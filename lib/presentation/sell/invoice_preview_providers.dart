/// Riverpod wiring for the Sell-tab **invoice preview + finalize** surface
/// (task 11.5).
///
/// This composes the pieces the preview and the gated FINALIZE button need and
/// nothing else, reusing the shared providers rather than redeclaring them:
///
///   * the staged structured requests (`draftOrderRequestsProvider`) and the
///     resulting [OrderAllocation] (`orderAllocationProvider`) from
///     `allocation_review_providers.dart` — the allocation the preview bills;
///   * the policy singletons `taxModeProvider` and `loadingPolicyProvider` from
///     `policy_providers.dart`, so the preview and a later finalize resolve the
///     SAME tax/loading policy as every other surface;
///   * the catalog/pricing reads over the shared [appDatabaseProvider] (the
///     [PricingService] rate per variety × cross-section and the confirmed
///     sellable balance + variety name + SKU label per stock item); and
///   * the `AuthService` gate (`authServiceProvider`), the connectivity flag
///     ([connectivityProvider]), the `HostedDatabase` seam
///     (`hostedDatabaseProvider`) and the headless [FinalizeService] that runs
///     the single authenticated hosted transaction.
///
/// ## Preview NEVER mutates stock
///
/// Building the preview is a pure read: it resolves the allocation, prices each
/// line with the stored rate, and runs `BillingService.computeTotals` to get
/// the goods subtotal, the single tax line, the loading charge, and the
/// payable (design.md -> Screen Flows -> Sell tab: Invoice preview). It writes
/// NOTHING to inventory, drafts, or invoices — a draft/preview never reaches
/// `FinalizeService` and never deducts stock (Requirement 12.1, 12.5, 21.21).
/// The screen surfaces this explicitly so the owner knows a preview is safe.
///
/// ## FINALIZE is GATED
///
/// Finalize is permitted only when ALL of these hold (design.md -> Sell tab:
/// Finalize; Requirements 4.7, 12.2, 12.3b, 17.14):
///
///   * an authenticated owner session exists (`AuthService.isAuthenticated`) —
///     else the order stays a draft and `NotAuthenticatedException` is surfaced
///     (Requirement 12.3b, 19.3);
///   * the device is online ([connectivityProvider]) — finalized billing is
///     cloud-confirmed and needs connectivity, else the order stays a draft
///     with a clear reason (Requirement 12.2, 12.3b);
///   * every sold line has a valid (strictly positive) rate — a missing rate is
///     flagged and blocks finalize (Requirement 4.7, 17.14); and
///   * the confirmed sellable stock covers every sold line (no insufficient
///     stock — Requirement 12.6).
///
/// The first blocking reason is reported as a [FinalizeGateReason] so the
/// screen can disable the button and explain why. Even if the button is somehow
/// pressed, `FinalizeService` re-validates inside the transaction and throws
/// [FinalizeBlockedException] / [NotAuthenticatedException], which the finalize
/// controller surfaces verbatim — the gate is advisory, the service is the
/// authority.
///
/// Architecture rule (design.md): providers live in the presentation layer and
/// compose the application/data layers. The data-layer `CategoryKind` is mapped
/// to the domain vocabulary through `InventoryQueryService`; the heavy money /
/// finalize math stays in the headless services.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/allocation_service.dart';
import 'package:wood_cft/application/auth_providers.dart';
import 'package:wood_cft/application/auth_service.dart';
import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/application/finalize_service.dart';
import 'package:wood_cft/application/inventory_query_service.dart';
import 'package:wood_cft/application/pricing_service.dart';
import 'package:wood_cft/data/hosted_database_providers.dart';
import 'package:wood_cft/data/local_invoice_writer.dart';
import 'package:wood_cft/data/price_rate_repository.dart';
import 'package:wood_cft/domain/money.dart';
import 'package:wood_cft/presentation/sell/allocation_review_providers.dart';
import 'package:wood_cft/presentation/settings/policy_providers.dart';

export 'package:wood_cft/presentation/sell/allocation_review_providers.dart'
    show appDatabaseProvider, draftOrderRequestsProvider, orderAllocationProvider;
export 'package:wood_cft/presentation/settings/policy_providers.dart'
    show taxModeProvider, loadingPolicyProvider;

/// Why a finalize is currently blocked, in the design's gate order (design.md
/// -> Sell tab: Invoice preview / Finalize; Requirements 4.7, 12.2, 12.3b).
enum FinalizeGateReason {
  /// Nothing to finalize: either no order lines are staged, or the allocation
  /// is fully shorted (zero allocated pieces — no confirmed stock to sell), so
  /// finalizing would issue a 0 CFT / ₹0.00 "sale" (FIX 2).
  emptyOrder,

  /// No authenticated owner session — the order stays a draft (Req 12.3b,
  /// 19.3; surfaces [NotAuthenticatedException] on an attempt).
  notAuthenticated,

  /// The device is offline — finalized billing needs connectivity, so the
  /// order stays a draft with a clear reason (Req 12.2, 12.3b).
  offline,

  /// At least one sold line references a stock item with no valid rate — a
  /// missing rate is flagged and blocks finalize (Req 4.7, 17.14).
  missingRate,

  /// At least one sold line exceeds the confirmed sellable stock (Req 12.6).
  insufficientStock,
}

/// The computed invoice preview + the finalize gate for the current draft.
///
/// This is a pure read-only value: it carries the billed [totals] (goods / tax
/// / loading / payable) from the shared calculation, the priced [lines] the
/// preview renders, whether the proposal is a [isPartial] allocation, and the
/// single blocking [gate] reason (or `null` when finalize is allowed). It never
/// mutates stock (Requirement 12.1, 12.5, 21.21).
@immutable
class InvoicePreview {
  /// Creates an invoice preview.
  const InvoicePreview({
    required this.lines,
    required this.totals,
    required this.isPartial,
    required this.gate,
    required this.missingRateItemIds,
    required this.insufficientItemIds,
  });

  /// The priced goods lines in allocation order (each with its rounded amount).
  final List<InvoicePreviewLine> lines;

  /// The full bill math: goods subtotal, the single tax line, the loading
  /// charge, and the payable grand total (via `BillingService`).
  final InvoiceTotals totals;

  /// Whether the underlying allocation is a clearly-labelled partial (any line
  /// could not be fully met from confirmed stock — Requirement 8.4).
  final bool isPartial;

  /// The single blocking reason, or `null` when finalize is allowed.
  final FinalizeGateReason? gate;

  /// Stock-item ids of sold lines whose rate is missing (for flagging in the
  /// UI — Requirement 4.7, 17.14).
  final Set<int> missingRateItemIds;

  /// Stock-item ids of sold lines that exceed confirmed stock (Req 12.6).
  final Set<int> insufficientItemIds;

  /// Whether finalize is currently permitted (no blocking [gate]).
  bool get canFinalize => gate == null;
}

/// A single priced line on the invoice preview.
@immutable
class InvoicePreviewLine {
  /// Creates a priced preview line.
  const InvoicePreviewLine({
    required this.stockItemId,
    required this.varietyName,
    required this.label,
    required this.lengthFt,
    required this.pieces,
    required this.cft,
    required this.rate,
    required this.amount,
    required this.hasRate,
  });

  /// The source stock item.
  final int stockItemId;

  /// The variety name (snapshot candidate; display here).
  final String varietyName;

  /// The SKU inch label, e.g. `2 × 1 in`.
  final String label;

  /// The piece length in feet.
  final int lengthFt;

  /// The allocated pieces for this line.
  final int pieces;

  /// The exact allocated volume.
  final Rational cft;

  /// The exact ₹/CFT rate, or `null` when the rate is missing (flagged).
  final Rational? rate;

  /// The rounded line amount, or `null` when the rate is missing.
  final Money? amount;

  /// Whether this line has a valid (strictly positive) rate.
  final bool hasRate;
}

/// A per-line resolution of a sold allocation line against the catalog, pricing
/// and confirmed stock — the raw material the preview and finalize both consume.
@immutable
class _ResolvedLine {
  const _ResolvedLine({
    required this.line,
    required this.varietyName,
    required this.label,
    required this.rate,
    required this.confirmedPieces,
  });

  final AllocationLine line;
  final String varietyName;
  final String label;
  final Rational? rate;
  final int confirmedPieces;
}

/// The device connectivity flag the finalize gate reads (design.md: finalized
/// billing is cloud-confirmed and needs connectivity — Requirement 12.2,
/// 12.3b).
///
/// Defaults to `true` (online). A real implementation would wire a
/// connectivity plugin here; tests and the offline-draft path override it to
/// `false` to assert the order stays a draft with a clear reason. Kept in the
/// Sell presentation scope (task 11.5) since no shared connectivity provider
/// exists yet.
final connectivityProvider = Provider<bool>((ref) => true);

/// Resolves each sold allocation line against the catalog (variety name + SKU
/// label), the stored rate, and the confirmed sellable balance.
final _resolvedLinesProvider =
    FutureProvider<List<_ResolvedLine>>((ref) async {
  final allocation = await ref.watch(orderAllocationProvider.future);
  if (allocation == null || allocation.lines.isEmpty) {
    return const [];
  }

  final db = ref.watch(appDatabaseProvider);
  final pricing = PricingService(PriceRateRepository(db));
  final inventory = InventoryQueryService(db);

  // One inventory read gives variety name, SKU label and confirmed balance per
  // stock item (confirmed-only — Requirement 19.8). Index by stock-item id.
  final rows = await inventory.query(const InventoryFilter());
  final byItem = <int, InventoryRow>{for (final r in rows.rows) r.stockItemId: r};

  final resolved = <_ResolvedLine>[];
  for (final line in allocation.lines) {
    final row = byItem[line.stockItemId];
    final rate = await pricing.rateFor(
      varietyId: line.varietyId,
      crossSectionId: line.crossSectionId,
    );
    resolved.add(
      _ResolvedLine(
        line: line,
        varietyName: row?.varietyName ?? 'Variety #${line.varietyId}',
        label: row?.crossSectionLabel ?? '#${line.crossSectionId}',
        rate: (rate != null && rate > Rational.zero) ? rate : null,
        confirmedPieces: row?.availablePieces ?? 0,
      ),
    );
  }
  return resolved;
});

/// The computed invoice preview + finalize gate for the current draft.
///
/// Returns `null` when the draft is empty. Prices every sold line with its
/// stored rate (missing rates priced at zero only for display — they are
/// flagged and block finalize), runs `BillingService.computeTotals` for the
/// totals, and computes the single blocking [FinalizeGateReason] in the
/// design's order. This is a pure read — it NEVER mutates stock (Req 12.1,
/// 12.5, 21.21).
final invoicePreviewProvider = FutureProvider<InvoicePreview?>((ref) async {
  final requests = ref.watch(draftOrderRequestsProvider);
  if (requests.isEmpty) {
    return null;
  }

  final allocation = await ref.watch(orderAllocationProvider.future);
  if (allocation == null || allocation.lines.isEmpty) {
    return null;
  }

  final resolved = await ref.watch(_resolvedLinesProvider.future);
  final isPartial = allocation.isPartial;
  final taxMode = ref.watch(taxModeProvider);
  final loadingPolicy = ref.watch(loadingPolicyProvider);
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  final isOnline = ref.watch(connectivityProvider);

  const billing = BillingService();

  // Price only the lines that HAVE a rate for the goods math; a missing-rate
  // line is flagged and blocks finalize (so its amount is not billed here).
  final goodsInputs = <GoodsLineInput>[];
  final previewLines = <InvoicePreviewLine>[];
  final missingRateItemIds = <int>{};
  final insufficientItemIds = <int>{};

  // Insufficient confirmed stock surfaces two ways, both of which block
  // finalize (Req 12.6): the allocator never over-allocates, so a demand it
  // could not cover comes back as a clearly-labelled PARTIAL line
  // (`isPartial`); and, defensively, a sold line whose allocated pieces exceed
  // the confirmed balance (summed per stock item for repeated draws) is a hard
  // shortage that FinalizeService's in-transaction revalidation would reject.
  final demandByItem = <int, int>{};
  for (final r in resolved) {
    demandByItem[r.line.stockItemId] =
        (demandByItem[r.line.stockItemId] ?? 0) + r.line.allocatedPieces;
  }
  for (final r in resolved) {
    if (r.line.isPartial ||
        demandByItem[r.line.stockItemId]! > r.confirmedPieces) {
      insufficientItemIds.add(r.line.stockItemId);
    }
  }

  for (final r in resolved) {
    final hasRate = r.rate != null;
    final rate = r.rate;
    Money? amount;
    if (hasRate) {
      amount = billing.lineAmount(r.line.allocatedCft, rate!);
      goodsInputs.add(
        GoodsLineInput(
          stockItemId: r.line.stockItemId,
          varietyId: r.line.varietyId,
          crossSectionId: r.line.crossSectionId,
          lengthFt: r.line.lengthFt,
          allocatedCft: r.line.allocatedCft,
          rate: rate,
        ),
      );
    } else {
      missingRateItemIds.add(r.line.stockItemId);
    }
    previewLines.add(
      InvoicePreviewLine(
        stockItemId: r.line.stockItemId,
        varietyName: r.varietyName,
        label: r.label,
        lengthFt: r.line.lengthFt,
        pieces: r.line.allocatedPieces,
        cft: r.line.allocatedCft.value,
        rate: rate,
        amount: amount,
        hasRate: hasRate,
      ),
    );
  }

  final goods = billing.computeGoods(goodsInputs);
  final totals = billing.computeTotals(goods, taxMode, policy: loadingPolicy);

  // FIX 2: block finalize of an empty / fully-shorted allocation. When the
  // allocation yields zero allocated pieces (no confirmed stock to sell),
  // there is nothing to finalize — finalizing would issue a 0 CFT / ₹0.00
  // "sale". This is checked first so it pre-empts the other gate reasons.
  final totalAllocatedPieces = resolved.fold<int>(
    0,
    (sum, r) => sum + r.line.allocatedPieces,
  );

  // Resolve the single blocking gate reason in the design's order:
  // zero-allocation -> auth -> connectivity -> missing rate -> insufficient
  // stock.
  FinalizeGateReason? gate;
  if (totalAllocatedPieces == 0) {
    gate = FinalizeGateReason.emptyOrder;
  } else if (!isAuthenticated) {
    gate = FinalizeGateReason.notAuthenticated;
  } else if (!isOnline) {
    gate = FinalizeGateReason.offline;
  } else if (missingRateItemIds.isNotEmpty) {
    gate = FinalizeGateReason.missingRate;
  } else if (insufficientItemIds.isNotEmpty) {
    gate = FinalizeGateReason.insufficientStock;
  }

  return InvoicePreview(
    lines: previewLines,
    totals: totals,
    isPartial: isPartial,
    gate: gate,
    missingRateItemIds: missingRateItemIds,
    insufficientItemIds: insufficientItemIds,
  );
});

/// The state of a finalize attempt the screen renders.
@immutable
class FinalizeState {
  /// Creates a finalize state.
  const FinalizeState({
    this.inProgress = false,
    this.invoice,
    this.error,
  });

  /// The idle initial state (nothing attempted yet).
  static const FinalizeState idle = FinalizeState();

  /// Whether a finalize is currently running.
  final bool inProgress;

  /// The issued invoice on success, else `null`.
  final FinalizedInvoice? invoice;

  /// A human-readable error (blocked reason / not authenticated), else `null`.
  final String? error;

  /// Whether a finalize has succeeded (an invoice was issued).
  bool get isSuccess => invoice != null;

  /// A copy with the given fields replaced.
  FinalizeState copyWith({
    bool? inProgress,
    FinalizedInvoice? invoice,
    String? error,
    bool clearInvoice = false,
    bool clearError = false,
  }) {
    return FinalizeState(
      inProgress: inProgress ?? this.inProgress,
      invoice: clearInvoice ? null : (invoice ?? this.invoice),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Drives a finalize attempt over the shared [FinalizeService], surfacing the
/// issued invoice on success and the [FinalizeBlockedException] /
/// [NotAuthenticatedException] reason on a block (task 11.5).
///
/// The controller composes the already-resolved lines (rates, labels, confirmed
/// stock) with the policy singletons and the hosted-DB seam, then calls
/// `FinalizeService.finalizeSale` inside its single authenticated transaction.
/// The service is the authority: even though the gate disables the button when
/// blocked, the controller still surfaces whatever the service throws so the
/// owner is told clearly and the order simply stays a draft.
final finalizeControllerProvider =
    NotifierProvider<FinalizeController, FinalizeState>(FinalizeController.new);

/// The finalize controller (see [finalizeControllerProvider]).
class FinalizeController extends Notifier<FinalizeState> {
  @override
  FinalizeState build() => FinalizeState.idle;

  /// Attempts to finalize the current draft into a permanent invoice.
  ///
  /// On success sets [FinalizeState.invoice] with the issued number; on a block
  /// or missing session sets [FinalizeState.error] with the service's reason
  /// and leaves the order a draft (nothing is written — Req 12.2, 12.3b).
  Future<void> finalize() async {
    state = const FinalizeState(inProgress: true);
    try {
      final allocation = await ref.read(orderAllocationProvider.future);
      if (allocation == null || allocation.lines.isEmpty) {
        state = const FinalizeState(error: 'There is nothing to finalize.');
        return;
      }
      // FIX 2: a fully-shorted allocation (zero allocated pieces) has nothing
      // to sell — refuse rather than issue a 0 CFT / ₹0.00 "sale".
      final allocatedPieces = allocation.lines
          .fold<int>(0, (sum, line) => sum + line.allocatedPieces);
      if (allocatedPieces == 0) {
        state = const FinalizeState(
          error: 'Nothing to finalize — no stock allocated.',
        );
        return;
      }
      final resolved = await ref.read(_resolvedLinesProvider.future);
      final taxMode = ref.read(taxModeProvider);
      final loadingPolicy = ref.read(loadingPolicyProvider);
      final auth = ref.read(authServiceProvider);
      final hosted = ref.read(hostedDatabaseProvider);

      // Build the finalize inputs from the resolved lines. A missing rate is
      // left out of the snapshots so the service blocks with a missingRate
      // reason (LineSnapshotInput also rejects a non-positive rate).
      final snapshots = <int, LineSnapshotInput>{};
      final confirmedById = <int, int>{};
      for (final r in resolved) {
        confirmedById[r.line.stockItemId] = r.confirmedPieces;
        final rate = r.rate;
        if (rate != null) {
          snapshots[r.line.stockItemId] = LineSnapshotInput(
            stockItemId: r.line.stockItemId,
            varietyId: r.line.varietyId,
            varietyName: r.varietyName,
            label: r.label,
            rate: rate,
          );
        }
      }
      final confirmedStock = [
        for (final entry in confirmedById.entries)
          ConfirmedStock(
            stockItemId: entry.key,
            confirmedPieces: entry.value,
          ),
      ];

      final service = FinalizeService(
        hostedDatabase: hosted,
        authService: auth,
      );

      // FIX 1: allocate a PERSISTENT, unique invoice number from the local DB
      // (max existing number + 1) and seed the allocator with it, so repeated
      // finalizes get INV-1, INV-2, INV-3… with no UNIQUE(invoiceNumber)
      // collision. The timestamp idempotency key makes each fresh finalize a
      // new sale; the local write below records the matching INV-<n> text.
      final db = ref.read(appDatabaseProvider);
      final writer = LocalInvoiceWriter(db);
      final nextNumber = await writer.nextInvoiceNumber();
      final idempotencyKey =
          'finalize:${DateTime.now().toUtc().toIso8601String()}';

      final invoice = await service.finalizeSale(
        allocation: allocation,
        snapshots: snapshots,
        confirmedStock: confirmedStock,
        taxMode: taxMode,
        numberAllocator: InMemoryInvoiceNumberAllocator(start: nextNumber),
        idempotencyKey: idempotencyKey,
        policy: loadingPolicy,
      );

      // Mirror the sale into the local tables (idempotent under the finalize
      // key) with the matching persistent invoice number.
      await writer.write(
        invoice,
        invoiceNumberText: 'INV-${invoice.number}',
      );
      state = FinalizeState(invoice: invoice);
    } on FinalizeBlockedException catch (e) {
      state = FinalizeState(error: e.reason);
    } on NotAuthenticatedException {
      state = const FinalizeState(
        error: 'Sign in to finalize. The order stays a draft until you do.',
      );
    } on Object catch (e) {
      state = FinalizeState(error: 'Could not finalize: $e');
    }
  }

  /// Resets the finalize state back to idle (e.g. to dismiss a result/error).
  void reset() => state = FinalizeState.idle;
}
