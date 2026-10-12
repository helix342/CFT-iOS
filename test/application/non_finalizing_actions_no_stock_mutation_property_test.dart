// Property-based test for task 11.6 / Property 18 — non-finalizing actions
// never mutate stock.
//
// Property 18 - Non-finalizing actions never mutate stock (design.md ->
// Correctness Properties; Requirements 12.1, 12.5, 15.6, 21.21):
//
//   For every order and confirmed-stock snapshot, EVERY non-finalizing action
//   — building an order (allocation), pricing/previewing it (billing),
//   generating the DOCX bytes and the WhatsApp bill text, and sharing/copying
//   through the share sheet — leaves the authoritative confirmed stock
//   UNCHANGED. No stock is deducted, and the only path that ever writes a
//   deduction to the authoritative store is `FinalizeService.finalizeSale`.
//
// How the invariant is observed. The authoritative store is the in-memory
// `FakeHostedDatabase`, whose `appliedCount` / `hasApplied` expose exactly how
// many idempotent effects (finalize invoices + `Sale` movements) have been
// committed. A stock deduction can ONLY reach the store through
// `FinalizeService.finalizeSale`, which stages a `finalizeInvoice` op plus one
// `Sale` movement per line. So "stock is unchanged" is precisely
// `appliedCount == 0` with no finalize/sale key applied. This test drives all
// the non-finalizing actions, each an arbitrary number of times, against that
// store and asserts the count never moves off zero — then, as the contrast,
// runs the one finalizing action and asserts it DOES deduct (so the invariant
// is non-vacuous: the store would have recorded a deduction had any
// non-finalizing action performed one).
//
// Across random orders/snapshots the actions exercised per run are:
//   * build the order            — `AllocationService.allocateOrder`
//   * price / preview            — `BillingService.computeGoods/computeTotals`
//   * generate DOCX              — `DocxExportService.buildDocx`
//   * generate WhatsApp text     — `WhatsAppExportService.buildMessage`
//   * share file / text, copy    — `InvoiceShareService` over a fake backend
// each repeated a random number of times. None touch the hosted store.
//
// PBT framework: `package:glados`. `ExploreConfig(numRuns: ...)` fixes the
// iteration count (>= 150) and seeds a deterministic `Random`, so any failure
// reproduces exactly.
//
// Headless: imports only the domain + application layers, `package:rational`,
// and `package:glados` (which re-exports `package:matcher`'s `expect`). No
// device, no network, no Flutter widgets — runs under `flutter test` on
// Windows.

import 'package:glados/glados.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/allocation_service.dart';
import 'package:wood_cft/application/auth_service.dart';
import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/application/docx_export_service.dart' as docx_model;
import 'package:wood_cft/application/finalize_service.dart';
import 'package:wood_cft/application/invoice_share_service.dart';
import 'package:wood_cft/application/whatsapp_export_service.dart';
import 'package:wood_cft/data/hosted_database.dart';
import 'package:wood_cft/domain/business_settings.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/order_request.dart';

/// Deterministic exploration config giving the property >= 150 iterations from
/// a fixed seed.
final ExploreConfig _explore =
    ExploreConfig(numRuns: 180, random: Random(20240916));

/// A single stock item in the shared pool: a cross-section (reaper 2×1 or plank
/// 4×1), a length 2..9 ft, and confirmed available pieces.
class _Stock {
  const _Stock({
    required this.isReaper,
    required this.lengthIndex,
    required this.pieces,
  });

  /// Reaper (bunch size 10) when true, plank (bunch size 1) when false.
  final bool isReaper;

  /// Length index 0..7 → feet 2..9.
  final int lengthIndex;

  /// Confirmed available pieces (0..).
  final int pieces;

  int get lengthFt => 2 + lengthIndex;
}

/// A single request line targeting one of the pool's stock items by index.
class _Line {
  const _Line({
    required this.stockIndex,
    required this.wantUnits,
    required this.useFixedLength,
    required this.targetNum,
  });

  /// Which pool stock item this line aims at (reduced mod pool size).
  final int stockIndex;

  /// For an exact-quantity line, the whole sale units demanded (1..).
  final int wantUnits;

  /// When true the line is a fixed-length target-CFT request; otherwise an
  /// exact-quantity request. Both pin a single SKU.
  final bool useFixedLength;

  /// Numerator (over 1) of a fixed-length target CFT (1..).
  final int targetNum;
}

/// A whole random scenario: a non-empty stock pool, an ordered list of request
/// lines, and how many times each non-finalizing action is replayed.
class _Scenario {
  const _Scenario({
    required this.stocks,
    required this.lines,
    required this.replays,
  });

  final List<_Stock> stocks;
  final List<_Line> lines;

  /// How many times every non-finalizing action is repeated (>= 1). Repeating
  /// is the heart of Property 18: running the actions "any number of times"
  /// still never mutates stock.
  final int replays;

  @override
  String toString() => '_Scenario(stocks: ${stocks.length}, '
      'lines: ${lines.length}, replays: $replays)';
}

final Generator<_Stock> _stock = any.combine3(
  any.bool,
  any.intInRange(0, 8), // length index 0..7 → 2..9 ft
  any.intInRange(0, 40), // pieces 0..39
  (bool isReaper, int lenIdx, int pieces) =>
      _Stock(isReaper: isReaper, lengthIndex: lenIdx, pieces: pieces),
);

final Generator<_Line> _line = any.combine4(
  any.intInRange(0, 50), // stock index (reduced mod pool size)
  any.intInRange(1, 8), // want units 1..7
  any.bool, // exact-qty vs fixed-length
  any.intInRange(1, 12), // fixed-length target numerator 1..11
  (int stockIndex, int wantUnits, bool useFixedLength, int targetNum) => _Line(
    stockIndex: stockIndex,
    wantUnits: wantUnits,
    useFixedLength: useFixedLength,
    targetNum: targetNum,
  ),
);

final Generator<_Scenario> _scenario = any.combine3(
  any.listWithLengthInRange(1, 6, _stock), // 1..5 stock items
  any.listWithLengthInRange(1, 7, _line), // 1..6 request lines
  any.intInRange(1, 4), // replay each action 1..3 times
  (List<_Stock> stocks, List<_Line> lines, int replays) =>
      _Scenario(stocks: stocks, lines: lines, replays: replays),
);

void main() {
  const calc = CalculationService();
  const allocator = AllocationService();
  const billing = BillingService();
  const docx = docx_model.DocxExportService();
  const whatsApp = WhatsAppExportService();

  // Fixed cross-sections: a reaper 2×1 (bunch size 10) and a plank 4×1.
  final reaper2x1 = CrossSection(
    id: 1,
    widthIn: 2,
    thicknessIn: 1,
    category: WoodCategory.reaper,
  );
  final plank4x1 = CrossSection(
    id: 2,
    widthIn: 4,
    thicknessIn: 1,
    category: WoodCategory.plank,
  );

  // Build the confirmed-availability pool for a scenario, collapsing duplicate
  // (cross-section, length) keys so each SKU is a unique row with a distinct
  // stockItemId (the snapshot needs one row per SKU).
  List<SkuAvailability> poolFor(_Scenario s) {
    final byKey = <String, SkuAvailability>{};
    var nextId = 1000;
    for (final st in s.stocks) {
      final crossSection = st.isReaper ? reaper2x1 : plank4x1;
      final key = '${crossSection.id}:${st.lengthFt}';
      if (byKey.containsKey(key)) {
        continue; // keep the first; one row per SKU
      }
      byKey[key] = SkuAvailability(
        stockItemId: nextId++,
        crossSection: crossSection,
        lengthFt: st.lengthFt,
        availablePieces: st.pieces,
      );
    }
    return byKey.values.toList();
  }

  // Build the ordered request lines, each pinned to one pool SKU.
  List<OrderRequest> requestsFor(_Scenario s, List<SkuAvailability> pool) {
    final requests = <OrderRequest>[];
    for (final ln in s.lines) {
      final sku = pool[ln.stockIndex % pool.length];
      if (ln.useFixedLength) {
        requests.add(
          TargetCftFixedLengthRequest(
            varietyId: 42,
            crossSectionId: sku.crossSection.id,
            lengthFt: sku.lengthFt,
            targetCft: Rational.fromInt(ln.targetNum),
          ),
        );
      } else {
        requests.add(
          ExactQtyRequest(
            varietyId: 42,
            crossSectionId: sku.crossSection.id,
            lengthFt: sku.lengthFt,
            quantityUnits: ln.wantUnits,
          ),
        );
      }
    }
    return requests;
  }

  // Price the allocated lines into billing totals (the preview/pricing action)
  // and assemble a shareable invoice snapshot from them. Pure value→value work
  // that never touches the hosted store.
  docx_model.InvoiceSnapshot previewSnapshot(OrderAllocation order) {
    final goodsInputs = <GoodsLineInput>[
      for (final l in order.lines)
        GoodsLineInput(
          stockItemId: l.stockItemId,
          varietyId: l.varietyId,
          crossSectionId: l.crossSectionId,
          lengthFt: l.lengthFt,
          allocatedCft: l.allocatedCft,
          rate: Rational.fromInt(1200),
        ),
    ];
    final goods = billing.computeGoods(goodsInputs);
    final totals = billing.computeTotals(goods, TaxMode.eighteen);

    final snapLines = <docx_model.InvoiceLineSnapshot>[
      for (final input in goodsInputs)
        docx_model.InvoiceLineSnapshot(
          variety: 'Mahogany',
          crossSection: input.crossSectionId == reaper2x1.id
              ? '2 x 1 in'
              : '4 x 1 in',
          lengthFt: input.lengthFt,
          units: 'allocated',
          goods: billing.priceLine(input),
        ),
    ];

    return docx_model.InvoiceSnapshot(
      business: const BusinessProfile(
        name: 'Wood CFT Timbers',
        address: '12 Mill Road, Chennai',
        phone: '044-12345',
        gstin: '33ABCDE1234F1Z5',
        invoicePrefix: 'INV-',
      ),
      invoiceNumber: 'INV-PREVIEW',
      dateLabel: '21-05-2024',
      customerName: 'Ramesh Timber',
      customerPhone: '9876543210',
      lines: snapLines,
      totals: totals,
    );
  }

  Glados<_Scenario>(_scenario, _explore).test(
    'Feature: wood-cft-app, Property 18: Non-finalizing actions never mutate '
    'stock - across every random order and confirmed-stock snapshot, building '
    'the order, pricing/previewing, generating DOCX + WhatsApp text, and '
    'sharing/copying any number of times leaves the authoritative confirmed '
    'stock unchanged; only finalizeSale deducts (Requirements 12.1, 12.5, '
    '15.6, 21.21)',
    (_Scenario s) async {
      final pool = poolFor(s);
      if (pool.isEmpty) {
        return; // no stock → nothing to assert
      }
      final requests = requestsFor(s, pool);

      // Authenticated owner + the authoritative in-memory store. appliedCount
      // is the authoritative "has stock changed?" probe: a deduction can only
      // land here via finalizeSale, so it stays 0 while only non-finalizing
      // actions run.
      final auth = FakeAuthService(
        initialSession: const AuthSession(userId: 'owner'),
      );
      final hosted = FakeHostedDatabase(authService: auth);
      final backend = FakeShareBackend();
      final share = InvoiceShareService(backend: backend);

      // Baseline: nothing applied yet.
      expect(hosted.appliedCount, 0);

      // --- Run EVERY non-finalizing action, each `replays` times. None of
      // these may ever touch the hosted store (Property 18).
      OrderAllocation? order;
      for (var r = 0; r < s.replays; r++) {
        // (a) build the order (allocation).
        order = allocator.allocateOrder(requests, pool);

        // Allocation never over-draws the pool, and that is a pure proposal:
        // it computes but does not commit a deduction.
        final usedByItem = <int, int>{};
        for (final l in order.lines) {
          expect(l.allocatedPieces >= 0, isTrue);
          usedByItem[l.stockItemId] =
              (usedByItem[l.stockItemId] ?? 0) + l.allocatedPieces;
        }
        for (final a in pool) {
          expect((usedByItem[a.stockItemId] ?? 0) <= a.availablePieces, isTrue);
        }

        // (b) price / preview, then (c) DOCX, (d) WhatsApp text.
        final snapshot = previewSnapshot(order);
        final docxBytes = docx.buildDocx(snapshot);
        final text = whatsApp.buildMessage(snapshot);
        expect(docxBytes, isNotEmpty);
        expect(text, isNotEmpty);

        // (e) share file / share text / copy text (device seam faked).
        await share.shareInvoiceFile(snapshot);
        await share.shareBillText(snapshot);
        await share.copyBillText(snapshot);

        // INVARIANT after every single action replay: the authoritative store
        // recorded NOTHING — confirmed stock is unchanged (Req 12.1, 15.6,
        // 21.21).
        expect(
          hosted.appliedCount,
          0,
          reason: 'a non-finalizing action mutated the authoritative store',
        );
      }

      // The share backend did receive the payloads (the actions really ran),
      // yet the store is still untouched — the invariant is non-vacuous.
      expect(backend.sharedFiles.length, s.replays);
      expect(backend.sharedTexts.length, s.replays);
      expect(backend.copiedTexts.length, s.replays);
      expect(hosted.appliedCount, 0);

      // --- Contrast: the ONE finalizing action DOES deduct. Finalize a single
      // fully-stocked line so we can assert the store would have recorded a
      // deduction had any non-finalizing action performed one. This proves the
      // probe above is live, not always-zero.
      final sku = pool.first;
      final finalizeLine = AllocationLine(
        stockItemId: sku.stockItemId,
        crossSectionId: sku.crossSection.id,
        varietyId: 42,
        lengthFt: sku.lengthFt,
        unit: AllocationUnit.forCategory(sku.crossSection.category),
        allocatedUnits: 1,
        allocatedPieces: sku.crossSection.bunchSize,
        allocatedCft: calc.lineCftFor(
          sku.crossSection,
          sku.lengthFt,
          sku.crossSection.bunchSize,
        ),
        isPartial: false,
        shortageUnits: 0,
        shortagePieces: 0,
      );
      final finalizeService =
          FinalizeService(hostedDatabase: hosted, authService: auth);
      var deducted = 0;
      await finalizeService.finalizeSale(
        allocation: OrderAllocation(
          lineResults: const [],
          lines: [finalizeLine],
          isPartial: false,
        ),
        snapshots: <int, LineSnapshotInput>{
          sku.stockItemId: LineSnapshotInput(
            stockItemId: sku.stockItemId,
            varietyId: 42,
            varietyName: 'Mahogany',
            label: 'sku',
            rate: Rational.fromInt(1200),
          ),
        },
        confirmedStock: [
          ConfirmedStock(
            stockItemId: sku.stockItemId,
            // Always enough for the one bunch/piece we finalize.
            confirmedPieces: sku.crossSection.bunchSize,
          ),
        ],
        taxMode: TaxMode.eighteen,
        numberAllocator: InMemoryInvoiceNumberAllocator(start: 1),
        idempotencyKey: 'finalize-contrast',
        onDeductStock: (stockItemId, delta) => deducted += delta,
      );

      // Only finalize mutates: the store now holds the invoice + the Sale
      // movement, and the signed deduction fired exactly once.
      expect(deducted, -sku.crossSection.bunchSize);
      expect(hosted.hasApplied('finalize-contrast'), isTrue);
      expect(hosted.appliedCount, greaterThan(0));

      await auth.dispose();
    },
  );
}
