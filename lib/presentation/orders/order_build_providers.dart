/// Riverpod wiring for the adjustable order-build surface (app-ux-revamp
/// Requirement 3).
///
/// Holds the staged [StagedOrderLine]s the owner is tuning. Lines are keyed by
/// SKU ([StagedOrderLine.skuKey]) so adding the same SKU twice merges into one
/// line, and adjusting the quantity to zero removes the line entirely
/// (Requirement 3.4 — no zero-quantity lines ever persist). The running total
/// CFT is computed by the single shared `CalculationService`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/allocation_service.dart';
import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/application/pricing_service.dart';
import 'package:wood_cft/data/price_rate_repository.dart';
import 'package:wood_cft/domain/cft.dart';
import 'package:wood_cft/domain/money.dart';
import 'package:wood_cft/domain/order_request.dart';
import 'package:wood_cft/presentation/orders/staged_order_line.dart';
import 'package:wood_cft/presentation/orders/staged_target_request.dart';
import 'package:wood_cft/presentation/sell/allocation_review_providers.dart'
    show allocationServiceProvider, confirmedAvailabilityProvider;
import 'package:wood_cft/presentation/sell/sell_providers.dart'
    show appDatabaseProvider;

/// The single shared CFT engine for the order-build surface.
final orderBuildCalculationProvider = Provider<CalculationService>(
  (ref) => const CalculationService(),
);

/// The staged, adjustable order lines for the order currently being built.
final stagedOrderLinesProvider =
    NotifierProvider<StagedOrderLinesNotifier, List<StagedOrderLine>>(
  StagedOrderLinesNotifier.new,
);

/// Collects and mutates the staged adjustable order lines.
class StagedOrderLinesNotifier extends Notifier<List<StagedOrderLine>> {
  @override
  List<StagedOrderLine> build() => const [];

  /// Adds [line] (merging into an existing line with the same SKU). A
  /// non-positive quantity is ignored.
  void addLine(StagedOrderLine line) {
    if (line.quantityUnits <= 0) return;
    final index = state.indexWhere((l) => l.skuKey == line.skuKey);
    if (index == -1) {
      state = [...state, line];
      return;
    }
    final merged =
        state[index].withQuantity(state[index].quantityUnits + line.quantityUnits);
    final next = [...state];
    next[index] = merged;
    state = next;
  }

  /// Sets the quantity of the line at [index] to [quantityUnits]. A value of
  /// zero or below removes the line (Requirement 3.4).
  void setQuantityAt(int index, int quantityUnits) {
    if (index < 0 || index >= state.length) return;
    if (quantityUnits <= 0) {
      removeAt(index);
      return;
    }
    final next = [...state];
    next[index] = next[index].withQuantity(quantityUnits);
    state = next;
  }

  /// Removes the line at [index] (no-op when out of range).
  void removeAt(int index) {
    if (index < 0 || index >= state.length) return;
    final next = [...state]..removeAt(index);
    state = next;
  }

  /// Replaces all staged lines (used when resuming a saved order).
  void replaceAll(List<StagedOrderLine> lines) =>
      state = List<StagedOrderLine>.unmodifiable(
        lines.where((l) => l.quantityUnits > 0),
      );

  /// Clears every staged line.
  void clear() => state = const [];
}

/// The staged target-CFT requests for the order currently being built.
///
/// These run parallel to [stagedOrderLinesProvider]: an exact-quantity demand
/// is an adjustable [StagedOrderLine] (tuned with a +/- stepper), while a
/// target-CFT demand is a [StagedTargetRequest] whose unit count the allocator
/// decides (so it carries no stepper).
final stagedTargetRequestsProvider =
    NotifierProvider<StagedTargetRequestsNotifier, List<StagedTargetRequest>>(
  StagedTargetRequestsNotifier.new,
);

/// Collects and mutates the staged target-CFT requests.
class StagedTargetRequestsNotifier
    extends Notifier<List<StagedTargetRequest>> {
  @override
  List<StagedTargetRequest> build() => const [];

  /// Appends a target request to the staged set.
  void add(StagedTargetRequest request) => state = [...state, request];

  /// Removes the target request at [index] (no-op when out of range).
  void removeAt(int index) {
    if (index < 0 || index >= state.length) return;
    final next = [...state]..removeAt(index);
    state = next;
  }

  /// Replaces all staged target requests (used when resuming a saved order).
  void replaceAll(List<StagedTargetRequest> requests) =>
      state = List<StagedTargetRequest>.unmodifiable(requests);

  /// Clears every staged target request.
  void clear() => state = const [];
}

/// The exact running-total CFT across the staged lines (Requirement 3.5).
///
/// Computed order-independently via the shared engine so it matches the sum of
/// each line's exact CFT with no float drift (inherits Property 14).
final stagedOrderTotalCftProvider = Provider<Cft>((ref) {
  final calc = ref.watch(orderBuildCalculationProvider);
  final lines = ref.watch(stagedOrderLinesProvider);
  return calc.totalCft(
    lines.map(
      (l) => calc.lineCftFor(l.crossSection, l.lengthFt, l.pieces),
    ),
  );
});

/// The staged demand expressed as the structured [OrderRequest]s the allocation
/// engine consumes.
///
/// Each adjustable exact-quantity line becomes an [ExactQtyRequest]; each staged
/// target becomes its real target-CFT subtype ([TargetCftFixedLengthRequest],
/// [TargetCftFlexCrossSectionRequest] or [TargetCftFlexCategoryRequest]) so all
/// four request kinds reach the allocator as their true types.
final stagedOrderRequestsProvider = Provider<List<OrderRequest>>((ref) {
  final lines = ref.watch(stagedOrderLinesProvider);
  final targets = ref.watch(stagedTargetRequestsProvider);
  return [
    for (final l in lines)
      ExactQtyRequest(
        varietyId: l.varietyId,
        crossSectionId: l.crossSection.id,
        lengthFt: l.lengthFt,
        quantityUnits: l.quantityUnits,
      ),
    for (final t in targets) t.toRequest(),
  ];
});

/// Runs the shared `AllocationService` over the staged lines against confirmed
/// availability, exposing the [OrderAllocation] the review / finalize steps
/// consume. Returns `null` when nothing is staged.
final stagedOrderAllocationProvider =
    FutureProvider<OrderAllocation?>((ref) async {
  final requests = ref.watch(stagedOrderRequestsProvider);
  if (requests.isEmpty) return null;
  final availability = await ref.watch(confirmedAvailabilityProvider.future);
  final service = ref.watch(allocationServiceProvider);
  return service.allocateOrder(requests, availability);
});

/// The shared [PricingService] over the app database, so the build and review
/// surfaces read the SAME ₹/CFT rates as billing/finalize (FIX 5).
final orderBuildPricingProvider = Provider<PricingService>(
  (ref) => PricingService(PriceRateRepository(ref.watch(appDatabaseProvider))),
);

/// The ₹/CFT rate for a single variety × cross-section, or `null` when the cell
/// is unpriced. Rates are keyed by variety × cross-section only (never length).
final orderBuildRateProvider =
    FutureProvider.family<Rational?, ({int varietyId, int crossSectionId})>(
  (ref, key) async {
    final pricing = ref.watch(orderBuildPricingProvider);
    return pricing.rateFor(
      varietyId: key.varietyId,
      crossSectionId: key.crossSectionId,
    );
  },
);

/// The priced amount for a single staged exact-qty line (FIX 5).
///
/// Carries the resolved ₹/CFT [rate] (or `null` when unpriced) and the computed
/// line [amount] (exact line CFT × rate, rounded half-up to paise via
/// [BillingService.lineAmount]); [amount] is `null` when the rate is missing.
@immutable
class StagedLinePrice {
  /// Creates a priced staged line.
  const StagedLinePrice({required this.rate, required this.amount});

  /// The resolved ₹/CFT rate, or `null` when the cell is unpriced.
  final Rational? rate;

  /// The computed line amount, or `null` when the rate is missing.
  final Money? amount;
}

/// Prices a single staged `line`: resolves its ₹/CFT rate and computes the line
/// amount from the exact line CFT (FIX 5). Reactive — re-reads when the staged
/// line's SKU or quantity changes.
final stagedLinePriceProvider =
    FutureProvider.family<StagedLinePrice, StagedOrderLine>(
  (ref, line) async {
    final rate = await ref.watch(
      orderBuildRateProvider(
        (varietyId: line.varietyId, crossSectionId: line.crossSection.id),
      ).future,
    );
    if (rate == null) {
      return const StagedLinePrice(rate: null, amount: null);
    }
    final calc = ref.watch(orderBuildCalculationProvider);
    const billing = BillingService();
    final cft = calc.lineCftFor(line.crossSection, line.lengthFt, line.pieces);
    return StagedLinePrice(rate: rate, amount: billing.lineAmount(cft, rate));
  },
);

/// The exact ₹/CFT rate for the current build-form selection (used by the
/// CFT-per-piece readout to also show the rate), or `null` when unpriced (FIX
/// 5).
final buildSelectionRateProvider =
    FutureProvider.family<Rational?, ({int varietyId, int crossSectionId})>(
  (ref, key) => ref.watch(
    orderBuildRateProvider(
      (varietyId: key.varietyId, crossSectionId: key.crossSectionId),
    ).future,
  ),
);

/// The running total ₹ across all staged exact-qty lines (FIX 5).
///
/// Sums each line's amount (exact line CFT × rate, rounded per line) over the
/// lines that HAVE a rate; unpriced lines contribute nothing to the money
/// total (they are flagged elsewhere). Returns [Money.zero] when nothing is
/// staged or priced, alongside whether any staged line was unpriced.
final stagedOrderTotalAmountProvider =
    FutureProvider<({Money total, bool anyUnpriced})>((ref) async {
  final lines = ref.watch(stagedOrderLinesProvider);
  final calc = ref.watch(orderBuildCalculationProvider);
  const billing = BillingService();
  final pricing = ref.watch(orderBuildPricingProvider);

  var total = Money.zero;
  var anyUnpriced = false;
  for (final line in lines) {
    final rate = await pricing.rateFor(
      varietyId: line.varietyId,
      crossSectionId: line.crossSection.id,
    );
    if (rate == null) {
      anyUnpriced = true;
      continue;
    }
    final cft = calc.lineCftFor(line.crossSection, line.lengthFt, line.pieces);
    total += billing.lineAmount(cft, rate);
  }
  return (total: total, anyUnpriced: anyUnpriced);
});

/// The goods ₹ total for the REVIEWED allocation (FIX 5).
///
/// Prices each allocation line by the stored ₹/CFT rate (variety ×
/// cross-section) and sums the per-line amounts via [BillingService], so the
/// Orders review footer can surface the goods total the bill will charge. Lines
/// without a rate are skipped and flagged via `anyUnpriced`. Returns a zero
/// total when nothing is allocated.
final stagedOrderReviewAmountProvider =
    FutureProvider<({Money total, bool anyUnpriced})>((ref) async {
  final allocation = await ref.watch(stagedOrderAllocationProvider.future);
  if (allocation == null || allocation.lines.isEmpty) {
    return (total: Money.zero, anyUnpriced: false);
  }
  const billing = BillingService();
  final pricing = ref.watch(orderBuildPricingProvider);

  var total = Money.zero;
  var anyUnpriced = false;
  for (final line in allocation.lines) {
    final rate = await pricing.rateFor(
      varietyId: line.varietyId,
      crossSectionId: line.crossSectionId,
    );
    if (rate == null) {
      anyUnpriced = true;
      continue;
    }
    total += billing.lineAmount(line.allocatedCft, rate);
  }
  return (total: total, anyUnpriced: anyUnpriced);
});
