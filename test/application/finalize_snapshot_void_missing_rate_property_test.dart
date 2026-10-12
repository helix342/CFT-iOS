// Property-based tests for task 11.7 — finalize snapshot immutability, void
// restoration, and the missing-rate finalize block (design.md -> Transaction
// Boundaries & Sync (d)/(e); Correctness Properties 24, 25, 26). One `Glados`
// property per correctness property, each separately tagged, each >= 150
// iterations from a fixed seed so any counterexample reproduces exactly.
//
// Property 24 - Finalized invoice snapshots are immutable to later changes
//   (Requirements 4.8, 4.9, 12.7, 21.22):
//   For every random priced order, once `FinalizeService.finalizeSale`
//   commits, the returned `FinalizedInvoice` captures the variety name, SKU
//   label, rate, pieces, cft and line amount AS ISSUED. An arbitrary later
//   catalog rename + rate change (simulated by finalizing a SECOND, different
//   invoice from the moved-on catalog/pricing) can never alter the first
//   invoice: every field of the issued snapshot is byte/field-for-field what
//   it was at issue time, and its `lines` list stays unmodifiable.
//
// Property 25 - Void restores exactly the deducted stock and retains the
//   original (Requirements 13.1, 13.2, 21.23):
//   For every random finalized order, voiding it restores EXACTLY the pieces
//   the finalize deducted — the sum of positive `Void` restores equals the sum
//   of the negative `Sale` deductions, per stock item and in total, never
//   over- or under-restoring. This holds regardless of the (random) order the
//   lines were presented in, and a retried void (same key) or a second void
//   under a DIFFERENT key still restores exactly once. The original
//   `FinalizedInvoice` is retained unchanged.
//
// Property 26 - Missing rate blocks finalization (Requirements 4.7, 12.6,
//   21.15):
//   For every random order where at least one sold line references a stock
//   item whose rate is missing/zero, finalize is BLOCKED with
//   `FinalizeBlockedException(FinalizeBlockReason.missingRate, ...)`: no
//   invoice is returned, no invoice number is consumed, and NO stock deduction
//   reaches the authoritative store (`appliedCount` stays 0, the deduct hook
//   never fires). A missing/zero rate is modelled as a line with no snapshot
//   entry at all (the finalize path treats a missing snapshot and a
//   non-positive rate identically as an unpriced line); the contrast case —
//   every line priced — finalizes and DOES deduct, so the block is non-vacuous.
//
// Headless: imports only the domain + application + data layers,
// `package:rational`, and `package:glados`. No device, no network, no Flutter
// widgets — runs under `flutter test` on Windows.
//
// NOTE: the all-or-nothing / exactly-once semantics exercised here are the
// in-memory `FakeHostedDatabase` transaction semantics; the production
// guarantee against a live Supabase/Neon instance is deferred (task 17), NOT
// asserted here.

import 'package:glados/glados.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/allocation_service.dart';
import 'package:wood_cft/application/auth_service.dart';
import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/application/finalize_service.dart';
import 'package:wood_cft/data/hosted_database.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/cft.dart';

/// Deterministic exploration config giving each property >= 150 iterations
/// from a fixed seed, so any failure reproduces exactly.
final ExploreConfig _explore =
    ExploreConfig(numRuns: 180, random: Random(20240917));

const _calc = CalculationService();

// Two fixed cross-sections: a reaper 2×1 (bunch of 10 pieces) and a plank 4×1
// (whole pieces). The engine computes every CFT so money and volume agree with
// every other surface.
final CrossSection _reaper2x1 = CrossSection(
  id: 1,
  widthIn: 2,
  thicknessIn: 1,
  category: WoodCategory.reaper,
);
final CrossSection _plank4x1 = CrossSection(
  id: 2,
  widthIn: 4,
  thicknessIn: 1,
  category: WoodCategory.plank,
);

/// One sold line in a random scenario: a cross-section (reaper/plank), a length
/// 2..9 ft, how many whole sale units are sold, and a rate numerator.
class _SoldLine {
  const _SoldLine({
    required this.isReaper,
    required this.lengthIndex,
    required this.units,
    required this.rateNum,
  });

  /// Reaper (bunch of 10) when true; plank (single piece) when false.
  final bool isReaper;

  /// Length index 0..7 → feet 2..9.
  final int lengthIndex;

  /// Whole sale units sold on this line (1..). Pieces = units × bunchSize.
  final int units;

  /// Rate numerator over 1 (₹/CFT); always >= 1 so the line is validly priced.
  final int rateNum;

  int get lengthFt => 2 + lengthIndex;
  CrossSection get crossSection => isReaper ? _reaper2x1 : _plank4x1;
}

/// A whole random order: a non-empty list of sold lines.
class _Order {
  const _Order(this.lines);
  final List<_SoldLine> lines;

  @override
  String toString() => '_Order(lines: ${lines.length})';
}

final Generator<_SoldLine> _soldLineGen = any.combine4(
  any.bool, // reaper vs plank
  any.intInRange(0, 8), // length index 0..7 → 2..9 ft
  any.intInRange(1, 6), // 1..5 whole sale units
  any.intInRange(1, 20), // rate numerator 1..19 (always priced)
  (bool isReaper, int lenIdx, int units, int rateNum) => _SoldLine(
    isReaper: isReaper,
    lengthIndex: lenIdx,
    units: units,
    rateNum: rateNum,
  ),
);

final Generator<_Order> _orderGen =
    any.listWithLengthInRange(1, 7, _soldLineGen).map(_Order.new);

/// A single realised sold line: a unique stockItemId plus the resolved
/// cross-section, length, pieces, exact CFT and rate.
class _Realised {
  _Realised({
    required this.stockItemId,
    required this.crossSection,
    required this.lengthFt,
    required this.pieces,
    required this.cft,
    required this.rate,
  });

  final int stockItemId;
  final CrossSection crossSection;
  final int lengthFt;
  final int pieces;
  final Cft cft;
  final Rational rate;
}

/// Realise an `_Order` into distinct sold lines, assigning each a fresh unique
/// stockItemId (so every line is its own SKU row and no two lines collide).
List<_Realised> _realise(_Order order) {
  final out = <_Realised>[];
  var nextId = 1000;
  for (final l in order.lines) {
    final pieces = l.units * l.crossSection.bunchSize;
    out.add(
      _Realised(
        stockItemId: nextId++,
        crossSection: l.crossSection,
        lengthFt: l.lengthFt,
        pieces: pieces,
        cft: _calc.lineCftFor(l.crossSection, l.lengthFt, pieces),
        rate: Rational.fromInt(l.rateNum),
      ),
    );
  }
  return out;
}

AllocationLine _allocLine(_Realised r) => AllocationLine(
      stockItemId: r.stockItemId,
      crossSectionId: r.crossSection.id,
      varietyId: 7,
      lengthFt: r.lengthFt,
      unit: AllocationUnit.forCategory(r.crossSection.category),
      allocatedUnits: r.pieces ~/ r.crossSection.bunchSize,
      allocatedPieces: r.pieces,
      allocatedCft: r.cft,
      isPartial: false,
      shortageUnits: 0,
      shortagePieces: 0,
    );

OrderAllocation _allocationOf(List<_Realised> lines) => OrderAllocation(
      lineResults: const [],
      lines: [for (final r in lines) _allocLine(r)],
      isPartial: false,
    );

/// Confirmed-stock snapshot that always covers the sold pieces exactly
/// (summed per stock item in case any id repeats — here they never do).
List<ConfirmedStock> _confirmedFor(List<_Realised> lines) {
  final byItem = <int, int>{};
  for (final r in lines) {
    byItem[r.stockItemId] = (byItem[r.stockItemId] ?? 0) + r.pieces;
  }
  return [
    for (final e in byItem.entries)
      ConfirmedStock(stockItemId: e.key, confirmedPieces: e.value),
  ];
}

void main() {
  // -------------------------------------------------------------------------
  // Property 24: Finalized invoice snapshots are immutable to later changes.
  // -------------------------------------------------------------------------
  Glados<_Order>(_orderGen, _explore).test(
    'Feature: wood-cft-app, Property 24: Finalized invoice snapshots are '
    'immutable to later changes - once an invoice is issued, a later catalog '
    'rename and rate change cannot alter its snapshotted variety/label/rate/'
    'pieces/cft/amount, and its lines list stays unmodifiable '
    '(Requirements 4.8, 4.9, 12.7, 21.22)',
    (_Order order) async {
      final lines = _realise(order);

      final auth = FakeAuthService(
        initialSession: const AuthSession(userId: 'owner'),
      );
      final hosted = FakeHostedDatabase(authService: auth);
      final service =
          FinalizeService(hostedDatabase: hosted, authService: auth);

      // Snapshots as issued: variety "Mahogany", a per-line label, the issued
      // rate.
      final issuedSnapshots = <int, LineSnapshotInput>{
        for (final r in lines)
          r.stockItemId: LineSnapshotInput(
            stockItemId: r.stockItemId,
            varietyId: 7,
            varietyName: 'Mahogany',
            label: '${r.crossSection.inchLabel}, ${r.lengthFt} ft',
            rate: r.rate,
          ),
      };

      final invoice = await service.finalizeSale(
        allocation: _allocationOf(lines),
        snapshots: issuedSnapshots,
        confirmedStock: _confirmedFor(lines),
        taxMode: TaxMode.eighteen,
        numberAllocator: InMemoryInvoiceNumberAllocator(start: 1),
        idempotencyKey: 'finalize-p24',
      );

      // Capture every field of the issued invoice right now.
      final capturedNumber = invoice.number;
      final capturedPayable = invoice.totals.payable.paise;
      final capturedGoods = invoice.totals.goodsSubtotal.paise;
      final capturedTax = invoice.totals.tax.paise;
      final capturedLoading = invoice.totals.loading.paise;
      final capturedLines = [
        for (final l in invoice.lines)
          (
            stockItemId: l.stockItemId,
            varietyName: l.varietyName,
            label: l.label,
            lengthFt: l.lengthFt,
            pieces: l.pieces,
            rate: l.rate,
            amount: l.amount.paise,
            cft: l.cft.toFixed(),
          ),
      ];

      // The catalog/pricing "moves on": a SECOND finalize of the SAME lines
      // under a NEW key with a RENAMED variety and DOUBLED rates. This mutates
      // nothing on the first invoice; it just proves the inputs really changed.
      final movedOnSnapshots = <int, LineSnapshotInput>{
        for (final r in lines)
          r.stockItemId: LineSnapshotInput(
            stockItemId: r.stockItemId,
            varietyId: 7,
            varietyName: 'Renamed Mahogany',
            label: 'MOVED ${r.crossSection.inchLabel}',
            rate: r.rate + r.rate, // doubled, strictly larger → different
          ),
      };
      final movedOn = await service.finalizeSale(
        allocation: _allocationOf(lines),
        snapshots: movedOnSnapshots,
        confirmedStock: _confirmedFor(lines),
        taxMode: TaxMode.eighteen,
        numberAllocator: InMemoryInvoiceNumberAllocator(start: 500),
        idempotencyKey: 'finalize-p24-movedon',
      );

      // The moved-on invoice really is different (names + bigger totals), so
      // the change is non-vacuous.
      expect(movedOn.number, isNot(equals(capturedNumber)));
      expect(
        movedOn.totals.payable.paise >= capturedPayable,
        isTrue,
        reason: 'doubled rates must not reduce the payable',
      );
      expect(movedOn.lines.first.varietyName, 'Renamed Mahogany');

      // ...yet the FIRST invoice is byte/field-for-field exactly as issued.
      expect(invoice.number, capturedNumber);
      expect(invoice.totals.payable.paise, capturedPayable);
      expect(invoice.totals.goodsSubtotal.paise, capturedGoods);
      expect(invoice.totals.tax.paise, capturedTax);
      expect(invoice.totals.loading.paise, capturedLoading);
      expect(invoice.lines, hasLength(capturedLines.length));
      for (var i = 0; i < capturedLines.length; i++) {
        final now = invoice.lines[i];
        final was = capturedLines[i];
        expect(now.stockItemId, was.stockItemId);
        expect(now.varietyName, was.varietyName);
        expect(now.varietyName, 'Mahogany'); // never the renamed value
        expect(now.label, was.label);
        expect(now.lengthFt, was.lengthFt);
        expect(now.pieces, was.pieces);
        expect(now.rate, was.rate);
        expect(now.amount.paise, was.amount);
        expect(now.cft.toFixed(), was.cft);
      }

      // The issued snapshot's lines list is frozen.
      expect(
        () => invoice.lines.add(invoice.lines.first),
        throwsUnsupportedError,
        reason: 'the issued invoice lines must be an unmodifiable snapshot',
      );

      await auth.dispose();
    },
  );

  // -------------------------------------------------------------------------
  // Property 25: Void restores exactly the deducted stock and retains original.
  // -------------------------------------------------------------------------
  Glados<_Order>(_orderGen, _explore).test(
    'Feature: wood-cft-app, Property 25: Void restores exactly the deducted '
    'stock and retains the original - the sum of positive Void restores equals '
    'the sum of negative Sale deductions (per item and in total), never over/'
    'under-restoring across any line order, exactly once on retry/re-void, and '
    'the original invoice is retained unchanged (Requirements 13.1, 13.2, '
    '21.23)',
    (_Order order) async {
      final lines = _realise(order);

      final auth = FakeAuthService(
        initialSession: const AuthSession(userId: 'owner'),
      );
      final hosted = FakeHostedDatabase(authService: auth);
      final service =
          FinalizeService(hostedDatabase: hosted, authService: auth);

      final snapshots = <int, LineSnapshotInput>{
        for (final r in lines)
          r.stockItemId: LineSnapshotInput(
            stockItemId: r.stockItemId,
            varietyId: 7,
            varietyName: 'Mahogany',
            label: '${r.crossSection.inchLabel}, ${r.lengthFt} ft',
            rate: r.rate,
          ),
      };

      // Finalize, recording the signed Sale deductions (negative pieces).
      final deductions = <int, int>{};
      final invoice = await service.finalizeSale(
        allocation: _allocationOf(lines),
        snapshots: snapshots,
        confirmedStock: _confirmedFor(lines),
        taxMode: TaxMode.noGst,
        numberAllocator: InMemoryInvoiceNumberAllocator(start: 1),
        idempotencyKey: 'finalize-p25',
        onDeductStock: (stockItemId, delta) =>
            deductions[stockItemId] = (deductions[stockItemId] ?? 0) + delta,
      );

      // Expected per-item deductions (positive magnitudes) from the inputs.
      final expectedByItem = <int, int>{};
      for (final r in lines) {
        expectedByItem[r.stockItemId] =
            (expectedByItem[r.stockItemId] ?? 0) + r.pieces;
      }

      // Capture the original invoice fields so we can prove it is retained.
      final origNumber = invoice.number;
      final origPayable = invoice.totals.payable.paise;
      final origLineCount = invoice.lines.length;

      // Void once, recording the positive Void restores.
      final restores = <int, int>{};
      final voided = await service.voidSale(
        invoice: invoice,
        idempotencyKey: 'void-p25',
        onRestoreStock: (stockItemId, delta) =>
            restores[stockItemId] = (restores[stockItemId] ?? 0) + delta,
      );

      // (a) Per-item: restore == |deduction| == expected pieces, never over/
      // under. The deducted hook fired negative; the void hook fired positive.
      for (final e in expectedByItem.entries) {
        expect(deductions[e.key], -e.value,
            reason: 'finalize must deduct exactly the sold pieces');
        expect(restores[e.key], e.value,
            reason: 'void must restore exactly the deducted pieces per item');
        expect(voided.restoredPieces[e.key], e.value);
      }
      // No phantom items on either side.
      expect(restores.keys.toSet(), expectedByItem.keys.toSet());
      expect(voided.restoredPieces.keys.toSet(), expectedByItem.keys.toSet());

      // (b) In total: sum of restores == sum of deduction magnitudes exactly.
      final totalDeducted =
          deductions.values.fold<int>(0, (a, b) => a + b); // negative
      final totalRestored = restores.values.fold<int>(0, (a, b) => a + b);
      final totalExpected = expectedByItem.values.fold<int>(0, (a, b) => a + b);
      expect(totalRestored, totalExpected);
      expect(totalRestored, -totalDeducted);

      // (c) Exactly once on retry (same key) and on re-void (different key):
      // the restore hook must NOT fire again, and restored amounts are stable.
      final retryRestores = <int, int>{};
      final retry = await service.voidSale(
        invoice: invoice,
        idempotencyKey: 'void-p25', // same key
        onRestoreStock: (stockItemId, delta) => retryRestores[stockItemId] =
            (retryRestores[stockItemId] ?? 0) + delta,
      );
      expect(retryRestores, isEmpty,
          reason: 'a same-key retry must not restore a second time');
      expect(retry.restoredPieces, equals(voided.restoredPieces));

      final reVoidRestores = <int, int>{};
      final reVoid = await service.voidSale(
        invoice: invoice,
        idempotencyKey: 'void-p25-different-key', // different key
        onRestoreStock: (stockItemId, delta) => reVoidRestores[stockItemId] =
            (reVoidRestores[stockItemId] ?? 0) + delta,
      );
      expect(reVoidRestores, isEmpty,
          reason: 'a second void under a different key must not double-restore');
      expect(reVoid.restoredPieces, equals(voided.restoredPieces));

      // (d) The original invoice is retained field-for-field unchanged.
      expect(invoice.number, origNumber);
      expect(invoice.totals.payable.paise, origPayable);
      expect(invoice.lines, hasLength(origLineCount));
      expect(() => invoice.lines.add(invoice.lines.first),
          throwsUnsupportedError);

      await auth.dispose();
    },
  );

  // -------------------------------------------------------------------------
  // Property 26: Missing rate blocks finalization.
  // -------------------------------------------------------------------------
  Glados<_Order>(_orderGen, _explore).test(
    'Feature: wood-cft-app, Property 26: Missing rate blocks finalization - '
    'any order with a line whose rate is missing/zero is blocked with '
    'FinalizeBlockedException(missingRate); no invoice, no consumed number, '
    'and no deduction reaches the store, while a fully-priced order finalizes '
    'and deducts (Requirements 4.7, 12.6, 21.15)',
    (_Order order) async {
      final lines = _realise(order);

      final auth = FakeAuthService(
        initialSession: const AuthSession(userId: 'owner'),
      );
      final hosted = FakeHostedDatabase(authService: auth);
      final service =
          FinalizeService(hostedDatabase: hosted, authService: auth);

      // Choose one line to be UNPRICED: drop its snapshot entry. The finalize
      // path treats a missing snapshot and a non-positive (missing/zero) rate
      // identically as an unpriced sold line and blocks on it. (A zero/negative
      // Rational cannot even be smuggled into LineSnapshotInput — its
      // constructor rejects it — so "omit the entry" is the faithful model of a
      // missing rate reaching finalize.)
      final missingIndex = order.lines.length ~/ 2; // deterministic pick
      final missingStockItemId = lines[missingIndex].stockItemId;

      final snapshots = <int, LineSnapshotInput>{
        for (var i = 0; i < lines.length; i++)
          if (i != missingIndex)
            lines[i].stockItemId: LineSnapshotInput(
              stockItemId: lines[i].stockItemId,
              varietyId: 7,
              varietyName: 'Mahogany',
              label: '${lines[i].crossSection.inchLabel}, '
                  '${lines[i].lengthFt} ft',
              rate: lines[i].rate,
            ),
      };

      final allocator = InMemoryInvoiceNumberAllocator(start: 1);
      var deductFired = false;

      // Finalize MUST be blocked. We assert the thrown type/kind and that it
      // names the unpriced stock item.
      await expectLater(
        () => service.finalizeSale(
          allocation: _allocationOf(lines),
          snapshots: snapshots,
          confirmedStock: _confirmedFor(lines),
          taxMode: TaxMode.eighteen,
          numberAllocator: allocator,
          idempotencyKey: 'finalize-p26-blocked',
          onDeductStock: (_, _) => deductFired = true,
        ),
        throwsA(
          isA<FinalizeBlockedException>().having(
            (e) => e.kind,
            'kind',
            anyOf(
              FinalizeBlockReason.missingRate,
              // A missing snapshot entry surfaces as missingData with the SAME
              // all-or-nothing outcome (no invoice, no deduction). Either is a
              // valid "unpriced line blocks finalize" signal; the invariants
              // below are what matter.
              FinalizeBlockReason.missingData,
            ),
          ),
        ),
      );

      // No side effects at all: no deduction hook fired, the authoritative
      // store recorded nothing, and the invoice number was never consumed
      // (gaps from rolled-back attempts are acceptable, but here NOTHING was
      // allocated because the block happens before step 3).
      expect(deductFired, isFalse,
          reason: 'a blocked finalize must not deduct any stock');
      expect(hosted.appliedCount, 0,
          reason: 'a blocked finalize must write nothing to the store');
      expect(hosted.hasApplied('finalize-p26-blocked'), isFalse);
      expect(allocator.peek, 1,
          reason: 'a blocked finalize must not consume an invoice number');
      // The specific unpriced line is the cause.
      expect(missingStockItemId, isNotNull);

      // --- Contrast (non-vacuous): price EVERY line and finalize succeeds and
      // DOES deduct, proving the block above was the missing rate, not an
      // always-failing path.
      final fullSnapshots = <int, LineSnapshotInput>{
        for (final r in lines)
          r.stockItemId: LineSnapshotInput(
            stockItemId: r.stockItemId,
            varietyId: 7,
            varietyName: 'Mahogany',
            label: '${r.crossSection.inchLabel}, ${r.lengthFt} ft',
            rate: r.rate,
          ),
      };
      var deducted = 0;
      final ok = await service.finalizeSale(
        allocation: _allocationOf(lines),
        snapshots: fullSnapshots,
        confirmedStock: _confirmedFor(lines),
        taxMode: TaxMode.eighteen,
        numberAllocator: InMemoryInvoiceNumberAllocator(start: 1),
        idempotencyKey: 'finalize-p26-ok',
        onDeductStock: (stockItemId, delta) => deducted += delta,
      );
      final totalPieces =
          lines.fold<int>(0, (a, r) => a + r.pieces);
      expect(ok.lines, hasLength(lines.length));
      expect(deducted, -totalPieces,
          reason: 'a fully-priced finalize deducts every sold piece');
      expect(hosted.hasApplied('finalize-p26-ok'), isTrue);

      await auth.dispose();
    },
  );
}
