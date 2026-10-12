/// Exact-quantity allocation for the Sell tab (task 8.1).
///
/// This is the simplest sell path and the first slice of the allocator: given a
/// structured [ExactQtyRequest] for one pinned SKU, [AllocationService.allocateExact]
/// validates the demand against **confirmed** available stock, computes the
/// exact allocated CFT through the single shared `CalculationService`, and
/// returns one [AllocationLine].
///
/// It implements the exact-quantity path of design.md -> Allocation Behavior
/// ([AllocationService.allocateExact]), the **single-SKU target-CFT
/// meet-or-exceed** path ([AllocationService.allocateTargetCftFixedLength],
/// task 9.1), the **flexible reaper 60/30/10 length-share heuristic**
/// ([AllocationService.allocateFlexibleReaper], task 9.2), and the **flexible
/// plank whole-piece min-excess fill** ([AllocationService.allocateFlexiblePlank],
/// task 9.3), and the **multi-line remaining-availability** composition
/// ([AllocationService.allocateOrder], task 9.4) that allocates each order line
/// against the stock LEFT by the earlier lines so no quantity is ever counted
/// twice (Property 10).
///
/// Target-CFT meet-or-exceed (design.md -> "Target handling", CD-3): for one
/// eligible SKU the required whole-unit count is
/// `required_units = ceil(target_CFT / CFT_per_sale_unit)` computed with EXACT
/// rational arithmetic — the `target / unitCft` quotient's `ceil()` is a
/// `BigInt`, so no `double` ever touches the count. A sale unit is a whole
/// bunch for a reaper and a whole piece for a plank. Meet-or-exceed (round up)
/// is the ONLY direction; there is no at-most or closest option. The ceiling
/// applies to the UNIT COUNT, never to money — billing always uses the actual
/// allocated CFT, never the requested target (Requirement 8.5).
///
/// Hard constraints enforced on this path (design.md -> "Hard constraints"):
///   * **Whole-unit rule** — a reaper's quantity is counted in whole bunches of
///     `CrossSection.bunchSize` (10) pieces; a plank in whole pieces. The
///     request already carries a whole-unit count, and the piece-equivalent is
///     resolved via `CalculationService.pieceEquivalent`, so a reaper
///     allocation is always a multiple of 10 pieces (Requirement 8.1).
///   * **Stock availability** — the allocated pieces never exceed the confirmed
///     available pieces for the SKU; only confirmed stock is sellable
///     (Requirement 8.1, 19.8).
///
/// Allocation honesty (Requirements 8.3, 8.4; design.md Property 8): when the
/// confirmed stock cannot cover the demand, the service **never silently
/// reduces** the request. It instead returns a clearly labelled **partial**
/// line — `isPartial == true` with `shortageUnits`/`shortagePieces` equal to
/// `demand − allocated` — allocating exactly the whole units that are actually
/// available. A partial is never presented as fulfilled.
///
/// Architecture rule (design.md): this service depends on `domain` and the
/// shared `CalculationService` only and MUST NOT import `package:flutter/*`, so
/// it runs headless under `flutter test` on Windows (no Cupertino UI — that is
/// task 8.2).
library;

import 'package:meta/meta.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/cft.dart';
import 'package:wood_cft/domain/order_request.dart';

/// The whole-unit input unit of an allocation line (mirrors the data-layer
/// `InputUnit`): a reaper allocates in [AllocationUnit.bunch]es, a plank in
/// [AllocationUnit.piece]s.
enum AllocationUnit {
  /// Whole bunches of `CrossSection.bunchSize` pieces (reapers).
  bunch,

  /// Whole individual pieces (planks).
  piece;

  /// The allocation unit implied by a cross-section's category.
  static AllocationUnit forCategory(WoodCategory category) =>
      category == WoodCategory.reaper
          ? AllocationUnit.bunch
          : AllocationUnit.piece;
}

/// A single proposed allocation line produced by [AllocationService].
///
/// Carries the allocated whole-unit count, its piece-equivalent, the exact
/// allocated CFT (via the shared `CalculationService`), and — when the stock
/// could not cover the demand — the partial label plus the exact shortage
/// (Requirements 8.3, 8.4). Mirrors the persisted `AllocationLine` columns
/// (design.md -> Data Models) without binding to the data layer.
@immutable
class AllocationLine {
  /// Creates an allocation line.
  const AllocationLine({
    required this.stockItemId,
    required this.crossSectionId,
    required this.varietyId,
    required this.lengthFt,
    required this.unit,
    required this.allocatedUnits,
    required this.allocatedPieces,
    required this.allocatedCft,
    required this.isPartial,
    required this.shortageUnits,
    required this.shortagePieces,
  });

  /// The source stock item this line draws from.
  final int stockItemId;

  /// The source cross-section.
  final int crossSectionId;

  /// The source variety.
  final int varietyId;

  /// The piece length in feet.
  final int lengthFt;

  /// Whether the quantities are counted in bunches or pieces.
  final AllocationUnit unit;

  /// The allocated quantity in whole sale units (bunches or pieces).
  final int allocatedUnits;

  /// The allocated quantity resolved to whole pieces (`units × bunchSize`).
  final int allocatedPieces;

  /// The exact CFT of the allocated pieces, from `CalculationService`.
  /// [Cft.zero] when nothing could be allocated.
  final Cft allocatedCft;

  /// Whether this line is a clearly-labelled **partial** — the confirmed stock
  /// could not cover the demand (Requirements 8.3, 8.4). `false` means the
  /// demand was met in full.
  final bool isPartial;

  /// The shortfall in whole sale units when [isPartial]: `demand − allocated`
  /// in units. Zero when fully satisfied. Never negative (no over-allocation on
  /// the exact-quantity path).
  final int shortageUnits;

  /// The shortfall resolved to whole pieces (`shortageUnits × bunchSize`).
  /// Zero when fully satisfied.
  final int shortagePieces;

  /// Whether the demand was satisfied in full (the inverse of [isPartial]).
  bool get isFullyAllocated => !isPartial;

  @override
  String toString() =>
      'AllocationLine(stockItemId: $stockItemId, lengthFt: $lengthFt, '
      'unit: ${unit.name}, allocatedUnits: $allocatedUnits, '
      'allocatedPieces: $allocatedPieces, '
      'allocatedCft: ${allocatedCft.toFixed()}, isPartial: $isPartial, '
      'shortageUnits: $shortageUnits, shortagePieces: $shortagePieces)';
}

/// The confirmed availability snapshot for a single pinned SKU, as the
/// exact-quantity allocator consumes it.
///
/// [availablePieces] is the CONFIRMED balance only (pending receiving stock is
/// never sellable — Requirement 19.8). The caller builds this from the stock
/// item + its cross-section (e.g. via `InventoryQueryService`); the allocator
/// stays headless and takes a plain snapshot so it is trivially testable.
@immutable
class SkuAvailability {
  /// Creates an availability snapshot for one SKU.
  SkuAvailability({
    required this.stockItemId,
    required this.crossSection,
    required this.lengthFt,
    required this.availablePieces,
  }) {
    if (availablePieces < 0) {
      throw ArgumentError.value(
        availablePieces,
        'availablePieces',
        'confirmed available pieces must not be negative',
      );
    }
  }

  /// The stock item's identity.
  final int stockItemId;

  /// The SKU's cross-section (its category fixes bunch vs piece, and its
  /// dimensions feed the CFT formula).
  final CrossSection crossSection;

  /// The SKU's piece length in feet.
  final int lengthFt;

  /// Confirmed (sellable) pieces available for this SKU. Never includes
  /// pending receiving stock.
  final int availablePieces;
}

/// Produces allocation proposals from structured order requests.
///
/// Task 8.1 ships only [allocateExact]; the constrained-CFT heuristic is task
/// 9.x.
class AllocationService {
  /// Creates an allocation service using the shared [CalculationService]
  /// (defaults to a `const CalculationService()`), so every CFT value matches
  /// the stock views, billing, and exports exactly.
  const AllocationService([this._calc = const CalculationService()]);

  final CalculationService _calc;

  /// Allocates an exact-quantity [request] against the confirmed
  /// [availability] of its pinned SKU (Requirements 7.2, 8.1, 8.3).
  ///
  /// The [request] and [availability] MUST describe the same SKU — the service
  /// asserts that the variety, cross-section, and length line up, so a caller
  /// cannot accidentally allocate one SKU's demand against another's stock.
  ///
  /// Behaviour:
  ///   * resolves the whole-unit demand to pieces via
  ///     `CalculationService.pieceEquivalent` (reaper → × bunch size; plank →
  ///     × 1), so the whole-unit hard constraint holds by construction;
  ///   * when the confirmed available pieces cover the demand, allocates the
  ///     full requested units and computes their exact CFT — a fully satisfied,
  ///     non-partial line;
  ///   * when they do not, allocates only the whole units that fit
  ///     (`availablePieces ÷ bunchSize`, floored) and returns a clearly
  ///     **labelled partial** whose `shortageUnits` is exactly
  ///     `demand − allocated` — it NEVER silently reduces the request to make
  ///     it look fulfilled (Requirements 8.3, 8.4);
  ///   * a reaper allocation is always a whole number of bunches, so its piece
  ///     count is always a multiple of the bunch size (Requirement 8.1).
  ///
  /// Returns a single [AllocationLine]. When the SKU has zero available pieces,
  /// the result is a partial with zero allocated and the full demand as the
  /// shortage.
  AllocationLine allocateExact(
    ExactQtyRequest request,
    SkuAvailability availability,
  ) {
    if (request.crossSectionId != availability.crossSection.id) {
      throw ArgumentError(
        'cross-section mismatch: request ${request.crossSectionId} vs '
        'availability ${availability.crossSection.id}',
      );
    }
    if (request.lengthFt != availability.lengthFt) {
      throw ArgumentError(
        'length mismatch: request ${request.lengthFt} ft vs availability '
        '${availability.lengthFt} ft',
      );
    }

    final crossSection = availability.crossSection;
    final bunchSize = crossSection.bunchSize;
    final unit = AllocationUnit.forCategory(crossSection.category);

    final requestedUnits = request.quantityUnits;
    // Whole-unit hard constraint: the piece-equivalent of a reaper request is
    // always a multiple of the bunch size (Requirement 8.1).
    final requestedPieces = _calc.pieceEquivalent(crossSection, requestedUnits);

    final availablePieces = availability.availablePieces;

    // How many WHOLE sale units actually fit in the confirmed stock. For a
    // plank bunchSize is 1 so this is just the available pieces; for a reaper
    // it floors to whole bunches, so we never allocate a fractional bunch.
    final availableUnits = availablePieces ~/ bunchSize;

    if (availableUnits >= requestedUnits) {
      // Full allocation: never over-allocate, never silently change the ask.
      final allocatedCft =
          _calc.lineCftFor(crossSection, availability.lengthFt, requestedPieces);
      return AllocationLine(
        stockItemId: availability.stockItemId,
        crossSectionId: crossSection.id,
        varietyId: request.varietyId,
        lengthFt: availability.lengthFt,
        unit: unit,
        allocatedUnits: requestedUnits,
        allocatedPieces: requestedPieces,
        allocatedCft: allocatedCft,
        isPartial: false,
        shortageUnits: 0,
        shortagePieces: 0,
      );
    }

    // Insufficient stock: allocate exactly the whole units that fit and label
    // the result a partial with the exact shortage. NO silent reduction — the
    // shortage is reported so the caller can present an honest partial.
    final allocatedUnits = availableUnits;
    final allocatedPieces = allocatedUnits * bunchSize;
    final shortageUnits = requestedUnits - allocatedUnits;
    final shortagePieces = requestedPieces - allocatedPieces;

    final allocatedCft = allocatedPieces > 0
        ? _calc.lineCftFor(crossSection, availability.lengthFt, allocatedPieces)
        : Cft.zero;

    return AllocationLine(
      stockItemId: availability.stockItemId,
      crossSectionId: crossSection.id,
      varietyId: request.varietyId,
      lengthFt: availability.lengthFt,
      unit: unit,
      allocatedUnits: allocatedUnits,
      allocatedPieces: allocatedPieces,
      allocatedCft: allocatedCft,
      isPartial: true,
      shortageUnits: shortageUnits,
      shortagePieces: shortagePieces,
    );
  }

  /// Allocates a single-SKU target-CFT [request] at its fixed length against
  /// the confirmed [availability] of its pinned SKU, meet-or-exceed (task 9.1,
  /// Requirements 7.6, 8.1, 8.2, 8.3, 8.5).
  ///
  /// The [request] pins exactly one eligible SKU — one variety + cross-section
  /// + length — so the single-SKU rule holds by construction. The service
  /// asserts the [request] and [availability] describe the SAME SKU (matching
  /// cross-section and length), so a caller cannot allocate one SKU's target
  /// against another's stock.
  ///
  /// Meet-or-exceed (design.md -> "Target handling"; CD-3):
  ///
  /// ```text
  /// unitCft        = cftPerBunch(reaper) | cftPerPiece(plank)   // exact rational
  /// required_units = ceil(target_CFT / unitCft)                 // exact BigInt
  /// ```
  ///
  /// The `ceil` is taken on the EXACT `target / unitCft` rational quotient, so
  /// `required_units` is the smallest whole-unit count whose CFT is `>=` the
  /// target — no `double` is ever involved. The ceiling applies to the unit
  /// COUNT only; the line is **billed on its actual allocated CFT**, never on
  /// the target (Requirement 8.5).
  ///
  /// Hard constraints (Requirement 8.1), all enforced here:
  ///   * **fixed length** — only [TargetCftFixedLengthRequest.lengthFt] is
  ///     used; a fixed-length request that cannot be met is NEVER silently
  ///     mixed with other lengths (Requirement 21.12). This method draws from a
  ///     single SKU at the one fixed length, so no other length can enter;
  ///   * **cross-section** — the request's pinned cross-section is the only one
  ///     drawn from (asserted against [availability]);
  ///   * **whole-unit rule** — a reaper's allocation is a whole number of
  ///     bunches (its piece-equivalent is always a multiple of the bunch size);
  ///     a plank's is whole pieces;
  ///   * **stock availability** — the allocated pieces never exceed the
  ///     confirmed available pieces; only confirmed stock is sellable, and the
  ///     request is NEVER silently reduced (Requirements 8.3, 19.8).
  ///
  /// Understock (Requirement 8.4): when the confirmed stock cannot reach the
  /// target with whole units — i.e. `availableUnits < required_units` — the
  /// result is a clearly-labelled **partial** (`isPartial == true`) allocating
  /// exactly the whole units that fit, with the shortage expressed as the
  /// target-vs-allocatable unit gap (`required_units − availableUnits`). A
  /// partial is NEVER presented as fulfilled.
  ///
  /// Returns a single [AllocationLine]. When nothing fits (zero available or
  /// less than one whole unit) the line is a partial with zero allocated.
  AllocationLine allocateTargetCftFixedLength(
    TargetCftFixedLengthRequest request,
    SkuAvailability availability,
  ) {
    if (request.crossSectionId != availability.crossSection.id) {
      throw ArgumentError(
        'cross-section mismatch: request ${request.crossSectionId} vs '
        'availability ${availability.crossSection.id}',
      );
    }
    if (request.lengthFt != availability.lengthFt) {
      throw ArgumentError(
        'length mismatch: request ${request.lengthFt} ft vs availability '
        '${availability.lengthFt} ft',
      );
    }

    final crossSection = availability.crossSection;
    final lengthFt = availability.lengthFt;
    final bunchSize = crossSection.bunchSize;
    final unit = AllocationUnit.forCategory(crossSection.category);

    // CFT of ONE whole sale unit at this fixed length, exact: a reaper's unit
    // is a bunch (× bunchSize pieces), a plank's unit is a single piece.
    final unitCft = unit == AllocationUnit.bunch
        ? _calc.cftPerBunch(crossSection, lengthFt)
        : _calc.cftPerPiece(crossSection, lengthFt);

    // required_units = ceil(target_CFT / CFT_per_sale_unit), EXACT arithmetic.
    // Dividing two Rationals is exact; ceil() returns a BigInt — no double, no
    // float drift. unitCft is strictly positive (positive dims, length ≥ 2),
    // so the quotient and its ceiling are well-defined.
    final quotient = request.targetCft / unitCft.value;
    final requiredUnits = quotient.ceil().toInt();

    // Whole units the confirmed stock can supply at this fixed length. For a
    // reaper this floors to whole bunches; for a plank bunchSize is 1.
    final availableUnits = availability.availablePieces ~/ bunchSize;

    if (availableUnits >= requiredUnits) {
      // Target met or exceeded with the smallest whole-unit count. Bill the
      // ACTUAL allocated CFT (requiredUnits × unitCft), never the target.
      final allocatedPieces = requiredUnits * bunchSize;
      final allocatedCft = requiredUnits > 0
          ? _calc.lineCftFor(crossSection, lengthFt, allocatedPieces)
          : Cft.zero;
      return AllocationLine(
        stockItemId: availability.stockItemId,
        crossSectionId: crossSection.id,
        varietyId: request.varietyId,
        lengthFt: lengthFt,
        unit: unit,
        allocatedUnits: requiredUnits,
        allocatedPieces: allocatedPieces,
        allocatedCft: allocatedCft,
        isPartial: false,
        shortageUnits: 0,
        shortagePieces: 0,
      );
    }

    // Understock: the fixed length cannot reach the target with whole units.
    // Allocate exactly what fits and label a partial with the target-vs-
    // allocatable shortage — never silently mix other lengths, never claim
    // fulfilled (Requirements 8.3, 8.4, 21.12).
    final allocatedUnits = availableUnits;
    final allocatedPieces = allocatedUnits * bunchSize;
    final shortageUnits = requiredUnits - allocatedUnits;
    final shortagePieces = shortageUnits * bunchSize;
    final allocatedCft = allocatedPieces > 0
        ? _calc.lineCftFor(crossSection, lengthFt, allocatedPieces)
        : Cft.zero;

    return AllocationLine(
      stockItemId: availability.stockItemId,
      crossSectionId: crossSection.id,
      varietyId: request.varietyId,
      lengthFt: lengthFt,
      unit: unit,
      allocatedUnits: allocatedUnits,
      allocatedPieces: allocatedPieces,
      allocatedCft: allocatedCft,
      isPartial: true,
      shortageUnits: shortageUnits,
      shortagePieces: shortagePieces,
    );
  }

  /// Allocates a flexible-length **reaper** target-CFT [request] across the
  /// provided per-length [availability] using the 60/30/10 length-share
  /// heuristic with deficit redistribution (task 9.2; Requirements 8.7, 8.8,
  /// 8.9, 8.10; design.md -> "Flexible reaper length-share heuristic").
  ///
  /// This is a **bounded, deterministic heuristic — NOT an optimal solver**
  /// (Requirement 8.12). Identical inputs (request + availability snapshot +
  /// [allow89ftFallback]) always produce an identical result (Requirement
  /// 21.11 repeatability). It is greedy and group-ordered; it does not
  /// enumerate the global minimum-excess combination (design.md -> "Stated
  /// limitations").
  ///
  /// Length groups and their approximate shares of the TARGET CFT, applied in
  /// the fixed objective order 60 -> 30 -> 10 (design.md CD-4):
  ///
  /// ```text
  /// {6, 7} ft = 60%    {3, 4, 5} ft = 30%    {2} ft = 10%
  /// ```
  ///
  /// 8 ft and 9 ft are **excluded by default** and are only eligible when
  /// [allow89ftFallback] is `true` (matching `AllocationPolicy
  /// .allow_8_9ft_fallback`; Requirement 8.9, OD-5). When the fallback is on,
  /// 8 ft and 9 ft join the preferred `{6,7}` group so they can absorb a
  /// deficit without changing the share weights. The shares are **approximate
  /// and stock-aware**, realized only as WHOLE BUNCHES (multiples of 10 pieces)
  /// — never loose pieces, never fractional bunches (Requirement 8.8).
  ///
  /// Within a group lengths are tried **lower length first**, then lower
  /// `StockItem` id (the stable tie-breaker — design.md "Deterministic
  /// objective order" step 4). Each length is met-or-exceeded for its share of
  /// the (possibly redistributed) group target with
  /// `ceil(groupTargetRemaining / cftPerBunch)` whole bunches, capped at the
  /// bunches actually available there — stock is never invented.
  ///
  /// Redistribution (Requirement 8.7 / design.md pseudocode): when a preferred
  /// group cannot meet its share from its own stock, the unmet CFT **deficit is
  /// carried forward** and added to the targets of the remaining eligible
  /// groups, which are then recomputed. After the group passes, a final
  /// meet-or-exceed sweep over ALL remaining eligible bunches (same
  /// lower-length / lower-id order) closes any residual gap, so available stock
  /// at non-preferred lengths is still used rather than wasted.
  ///
  /// Billing uses the **actual allocated CFT** of each line, never the target
  /// (Requirement 8.5). The overall result meets or exceeds the target when
  /// stock allows; otherwise it is a clearly-labelled **partial**
  /// ([FlexibleReaperAllocation.isPartial]) carrying the exact CFT shortage —
  /// understock is never presented as fulfilled (Requirement 8.4).
  ///
  /// The [request]'s cross-section MUST be a reaper, and every entry in
  /// [availability] MUST share that reaper cross-section (asserted); applying
  /// the reaper length-group shares to planks is explicitly forbidden
  /// (Requirement 8.10). Multi-line remaining-availability is task 9.4; here
  /// the one reaper cross-section's per-length stock is allocated in isolation.
  ///
  /// Returns a [FlexibleReaperAllocation] with one [AllocationLine] per length
  /// actually used (lower length first), plus the partial/shortage summary.
  FlexibleReaperAllocation allocateFlexibleReaper(
    TargetCftFlexCrossSectionRequest request,
    List<SkuAvailability> availability, {
    bool allow89ftFallback = false,
  }) {
    // All availability must describe the request's single reaper cross-section.
    for (final a in availability) {
      if (a.crossSection.id != request.crossSectionId) {
        throw ArgumentError(
          'cross-section mismatch: availability ${a.crossSection.id} is not '
          'the request cross-section ${request.crossSectionId}',
        );
      }
      if (a.crossSection.category != WoodCategory.reaper) {
        throw ArgumentError(
          'allocateFlexibleReaper requires a reaper cross-section; got '
          '${a.crossSection.category.name} (reaper length-group shares must '
          'never be applied to planks — Requirement 8.10)',
        );
      }
    }

    // Fixed objective order of the length groups and their shares (CD-4). With
    // the fallback on, 8 and 9 ft join the preferred group so they can absorb
    // demand without altering the 60/30/10 weights.
    final preferredLengths = <int>[
      6,
      7,
      if (allow89ftFallback) ...[8, 9],
    ];
    final groups = <_ReaperGroup>[
      _ReaperGroup(preferredLengths, Rational(BigInt.from(6), BigInt.from(10))),
      _ReaperGroup(const [3, 4, 5], Rational(BigInt.from(3), BigInt.from(10))),
      _ReaperGroup(const [2], Rational(BigInt.from(1), BigInt.from(10))),
    ];

    // Per-length mutable allocation state, keyed by length, built only from the
    // eligible availability (8/9 ft dropped unless the fallback is enabled).
    // Lengths with no stock are simply absent.
    final eligibleLengths = <int>{
      for (final g in groups) ...g.lengths,
    };
    final slots = <int, _LengthSlot>{};
    for (final a in availability) {
      if (!eligibleLengths.contains(a.lengthFt)) {
        continue; // 8/9 ft excluded by default (Requirement 8.9).
      }
      final availableBunches =
          a.availablePieces ~/ a.crossSection.bunchSize; // whole bunches only
      if (availableBunches <= 0) {
        continue;
      }
      // Collapse duplicate rows for the same length by summing their bunches;
      // keep the lowest stock-item id as the stable identity (tie-breaker).
      final existing = slots[a.lengthFt];
      if (existing == null) {
        slots[a.lengthFt] = _LengthSlot(
          lengthFt: a.lengthFt,
          stockItemId: a.stockItemId,
          crossSection: a.crossSection,
          unitCft: _calc.cftPerBunch(a.crossSection, a.lengthFt),
          availableBunches: availableBunches,
        );
      } else {
        existing.availableBunches += availableBunches;
        if (a.stockItemId < existing.stockItemId) {
          existing.stockItemId = a.stockItemId;
        }
      }
    }

    final target = request.targetCft;

    // Pass over the groups in fixed order, carrying any unmet share-deficit
    // forward so it is redistributed onto the remaining eligible groups
    // (design.md pseudocode: redistributeDeficitAmongEligibleGroups).
    var carriedDeficit = Rational.zero;
    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      // The group's base share of the overall target plus any deficit carried
      // from earlier preferred groups that could not meet their share.
      final groupTarget = (target * group.share) + carriedDeficit;
      final allocatedInGroup = _fillTowards(group.lengths, groupTarget, slots);
      final shortfall = groupTarget - allocatedInGroup;
      carriedDeficit = shortfall > Rational.zero ? shortfall : Rational.zero;
    }

    // Final meet-or-exceed sweep: if the overall target is still not reached,
    // use any remaining eligible bunches (lower length, then lower id) so
    // stock-aware shares never waste available stock. Caps at availability.
    final allocatedSoFar = _allocatedCft(slots);
    if (allocatedSoFar < target) {
      final allLengths = slots.keys.toList()..sort();
      _fillTowards(allLengths, target - allocatedSoFar, slots);
    }

    // Build the result lines, lower length first (stable order).
    final usedLengths = slots.values
        .where((s) => s.allocatedBunches > 0)
        .toList()
      ..sort((a, b) {
        final byLen = a.lengthFt.compareTo(b.lengthFt);
        return byLen != 0 ? byLen : a.stockItemId.compareTo(b.stockItemId);
      });

    final lines = <AllocationLine>[];
    var allocatedCft = Cft.zero;
    for (final slot in usedLengths) {
      final pieces = slot.allocatedBunches * slot.crossSection.bunchSize;
      final lineCft = _calc.lineCftFor(slot.crossSection, slot.lengthFt, pieces);
      allocatedCft += lineCft;
      lines.add(
        AllocationLine(
          stockItemId: slot.stockItemId,
          crossSectionId: slot.crossSection.id,
          varietyId: request.varietyId,
          lengthFt: slot.lengthFt,
          unit: AllocationUnit.bunch,
          allocatedUnits: slot.allocatedBunches,
          allocatedPieces: pieces,
          allocatedCft: lineCft,
          isPartial: false,
          shortageUnits: 0,
          shortagePieces: 0,
        ),
      );
    }

    // Understock: the eligible stock could not meet or exceed the target even
    // after redistribution and the final sweep. Label a partial carrying the
    // exact CFT shortage; never claim fulfilled (Requirement 8.4).
    final isPartial = allocatedCft.value < target;
    final shortageCft =
        isPartial ? Cft(target - allocatedCft.value) : Cft.zero;

    return FlexibleReaperAllocation(
      lines: lines,
      targetCft: Cft(target),
      allocatedCft: allocatedCft,
      isPartial: isPartial,
      shortageCft: shortageCft,
    );
  }

  /// Allocates a flexible-length **plank** target-CFT [request] across the
  /// provided per-length [availability] using a whole-piece min-excess fill
  /// (task 9.3; Requirements 8.10, 8.11; design.md -> "Flexible plank").
  ///
  /// Planks are counted in **whole pieces** (bunch size 1). The service rounds
  /// up to **meet or exceed** the target CFT while choosing the whole-piece
  /// combination with the **smallest excess CFT**, and resolves ties with the
  /// documented stable tie-breaker — lower `Length_Ft` first, then lower
  /// `StockItem` id (Requirement 8.11; design.md "Deterministic objective
  /// order" step 4). Identical inputs always produce an identical result
  /// (Requirement 8.12 repeatability).
  ///
  /// CRITICAL (Requirement 8.10, 21.13): planks **never** use the reaper
  /// 60/30/10 length-group shares/weights. This is a plain min-excess
  /// whole-piece fill — there is no share split, no preferred group, and no
  /// 8/9 ft exclusion. Every eligible plank length (2–9 ft) with stock is a
  /// candidate.
  ///
  /// How the minimum excess is found (deterministic, bounded):
  ///
  /// Every piece of the one plank cross-section has CFT `W×T×L/144`, so the
  /// `W×T/144` factor is shared and the total allocated CFT is proportional to
  /// the **length-units** sum `Σ (pieces_at_len × len)`. Meeting-or-exceeding
  /// the target with the smallest excess CFT is therefore equivalent to
  /// reaching the smallest length-unit sum that is `>=` the exact threshold
  /// `ceil(target × 144 / (W×T))` (an exact `BigInt`), bounded by the pieces
  /// actually available at each length. This is solved exactly with a small
  /// bounded dynamic program over achievable length-unit sums (lengths are the
  /// integers 2–9 and availability is finite), so the result is the true
  /// minimum-excess whole-piece option whenever stock allows — not merely a
  /// greedy guess. Among equal-excess solutions the reconstruction prefers
  /// lower lengths first, then lower stock-item ids, matching the tie-breaker.
  ///
  /// Billing uses the **actual allocated CFT** of each line, never the target
  /// (Requirement 8.5). When the eligible plank stock cannot reach the target
  /// even using every available piece, the result is a clearly-labelled
  /// **partial** ([FlexiblePlankAllocation.isPartial]) that allocates every
  /// available piece and carries the exact CFT shortage — understock is never
  /// presented as fulfilled (Requirement 8.4). The heuristic is bounded and is
  /// NOT claimed optimal beyond the stated scope (Requirement 8.12).
  ///
  /// The [request]'s cross-section MUST be a plank, and every entry in
  /// [availability] MUST share that plank cross-section (asserted); applying
  /// this path to a reaper cross-section is rejected so reaper length-group
  /// shares and plank min-excess can never be confused (Requirement 8.10).
  /// Multi-line remaining-availability is task 9.4; here the one plank
  /// cross-section's per-length stock is allocated in isolation.
  ///
  /// Returns a [FlexiblePlankAllocation] with one [AllocationLine] per length
  /// actually used (lower length first, then lower stock-item id), plus the
  /// partial/shortage summary.
  FlexiblePlankAllocation allocateFlexiblePlank(
    TargetCftFlexCrossSectionRequest request,
    List<SkuAvailability> availability,
  ) {
    // All availability must describe the request's single plank cross-section.
    for (final a in availability) {
      if (a.crossSection.id != request.crossSectionId) {
        throw ArgumentError(
          'cross-section mismatch: availability ${a.crossSection.id} is not '
          'the request cross-section ${request.crossSectionId}',
        );
      }
      if (a.crossSection.category != WoodCategory.plank) {
        throw ArgumentError(
          'allocateFlexiblePlank requires a plank cross-section; got '
          '${a.crossSection.category.name} (reaper length-group shares must '
          'never be applied via the plank path — Requirement 8.10)',
        );
      }
    }

    // Collapse per-length stock into one slot per length (summing duplicate
    // rows, keeping the lowest stock-item id as the stable identity). Planks
    // count in whole pieces, so a slot's capacity is its available pieces.
    final slots = <int, _PlankSlot>{};
    CrossSection? crossSection;
    for (final a in availability) {
      crossSection ??= a.crossSection;
      if (a.availablePieces <= 0) {
        continue;
      }
      final existing = slots[a.lengthFt];
      if (existing == null) {
        slots[a.lengthFt] = _PlankSlot(
          lengthFt: a.lengthFt,
          stockItemId: a.stockItemId,
          availablePieces: a.availablePieces,
        );
      } else {
        existing.availablePieces += a.availablePieces;
        if (a.stockItemId < existing.stockItemId) {
          existing.stockItemId = a.stockItemId;
        }
      }
    }

    final target = request.targetCft;

    // No eligible stock at all → fully-unmet partial with the whole target as
    // the shortage.
    if (crossSection == null || slots.isEmpty) {
      return FlexiblePlankAllocation(
        lines: const <AllocationLine>[],
        targetCft: Cft(target),
        allocatedCft: Cft.zero,
        isPartial: true,
        shortageCft: Cft(target),
      );
    }

    // Per-piece CFT shares the W×T/144 factor across all lengths, so the exact
    // CFT of a whole-piece selection is (W×T/144) × Σ(pieces × len). Meet-or-
    // exceed with the smallest excess CFT therefore reduces to the smallest
    // length-unit sum `S = Σ(pieces × len)` with `S >= thresholdUnits`, where
    //   thresholdUnits = ceil(target × 144 / (W×T))                 // exact
    // is the fewest length-units whose CFT reaches the target.
    final wt =
        BigInt.from(crossSection.widthIn * crossSection.thicknessIn);
    final thresholdRational =
        target * Rational(BigInt.from(kCftDivisor), wt);
    final thresholdUnits = thresholdRational.ceil().toInt();

    // Candidate lengths in the stable tie-break order (lower length first, then
    // lower stock-item id — length is the primary key, ids break any ties).
    final lengths = slots.keys.toList()
      ..sort((a, b) {
        final byLen = a.compareTo(b);
        return byLen != 0 ? byLen : slots[a]!.stockItemId.compareTo(
              slots[b]!.stockItemId,
            );
      });

    // The maximum length-unit sum the entire eligible stock can supply.
    var maxUnits = 0;
    for (final len in lengths) {
      maxUnits += len * slots[len]!.availablePieces;
    }

    if (maxUnits < thresholdUnits) {
      // Understock: even using every available piece cannot meet the target.
      // Allocate everything and label a partial with the exact CFT shortage.
      return _buildPlankAllocation(
        request: request,
        crossSection: crossSection,
        slots: slots,
        lengths: lengths,
        pieceCountByLength: {
          for (final len in lengths) len: slots[len]!.availablePieces,
        },
        target: target,
      );
    }

    // Bounded exact min-excess solve over achievable length-unit sums in the
    // window [thresholdUnits, thresholdUnits + maxLen - 1]. The smallest
    // reachable sum >= thresholdUnits is at most thresholdUnits + (maxLen - 1)
    // (adding one more of the shortest length can never overshoot by a whole
    // length), so a bounded DP over that cap finds the true minimum excess.
    final maxLen = lengths.last; // lengths sorted ascending
    final cap = thresholdUnits + maxLen; // inclusive-exclusive upper bound

    // reachable[s] == true when a length-unit sum of exactly s is achievable
    // with the available pieces; `from[s]` records the length used to reach s
    // (lowest length preferred) so the selection can be reconstructed with the
    // stable tie-breaker.
    final reachable = List<bool>.filled(cap + 1, false);
    final usedLen = List<int>.filled(cap + 1, 0);
    reachable[0] = true;
    // Bounded unbounded-knapsack-style fill, lengths ascending so lower lengths
    // are preferred when a sum is reachable multiple ways. Availability caps
    // the pieces per length.
    for (final len in lengths) {
      final avail = slots[len]!.availablePieces;
      // Count how many pieces of this length already contributed on the path to
      // each sum so we never exceed availability.
      final usedCount = List<int>.filled(cap + 1, 0);
      for (var s = len; s <= cap; s++) {
        if (reachable[s]) {
          continue; // keep the earliest (lower-length) path to this sum
        }
        final prev = s - len;
        if (prev >= 0 && reachable[prev] && usedCount[prev] < avail) {
          reachable[s] = true;
          usedLen[s] = len;
          usedCount[s] = usedCount[prev] + 1;
        }
      }
    }

    // Smallest achievable sum that meets or exceeds the threshold.
    var bestSum = -1;
    for (var s = thresholdUnits; s <= cap; s++) {
      if (reachable[s]) {
        bestSum = s;
        break;
      }
    }

    // Reconstruct the piece counts per length for bestSum. The DP preferred
    // lower lengths, so the reconstruction naturally favours the tie-breaker.
    final pieceCountByLength = <int, int>{for (final len in lengths) len: 0};
    if (bestSum > 0) {
      var s = bestSum;
      while (s > 0) {
        final len = usedLen[s];
        pieceCountByLength[len] = (pieceCountByLength[len] ?? 0) + 1;
        s -= len;
      }
    }

    return _buildPlankAllocation(
      request: request,
      crossSection: crossSection,
      slots: slots,
      lengths: lengths,
      pieceCountByLength: pieceCountByLength,
      target: target,
    );
  }

  /// Allocates a MULTI-LINE order against a single shared availability
  /// snapshot, line by line in order, so no stock quantity is ever counted
  /// twice (task 9.4; Requirements 8.4, 8.6, 8.12; design.md -> Allocation
  /// Behavior -> "Multi-line and understock"; Correctness Property 10).
  ///
  /// An order carries an ORDERED list of [requests] — any mix of the four
  /// structured shapes ([ExactQtyRequest], [TargetCftFixedLengthRequest],
  /// [TargetCftFlexCrossSectionRequest] reaper/plank). Each line is allocated
  /// against the **remaining** availability left by the earlier lines, so one
  /// stock item's pieces can never be allocated twice within the same order
  /// (Requirements 8.6, 21.14; Property 10).
  ///
  /// How remaining-availability works (design.md CD): the service keeps a
  /// mutable working copy of the confirmed available pieces, keyed by
  /// `stockItemId`, seeded from the full [availability] snapshot. For each
  /// request, in order, it reuses the matching per-request allocator
  /// ([allocateExact] / [allocateTargetCftFixedLength] /
  /// [allocateFlexibleReaper] / [allocateFlexiblePlank]) by feeding it a view
  /// of the stock items that still have pieces left. After the line is
  /// allocated, the pieces each produced [AllocationLine] consumed are
  /// subtracted from the working copy, so a later line only sees what remains.
  /// A later line therefore goes **partial** when an earlier line consumed the
  /// stock it would have drawn on — the shortage is reported honestly and
  /// never silently reduced (Requirements 8.3, 8.4).
  ///
  /// Per-line partial/shortage labelling is preserved: each line keeps its own
  /// [AllocationLine] / [FlexibleReaperAllocation] / [FlexiblePlankAllocation]
  /// result (with its `isPartial` + shortage), wrapped in an
  /// [OrderLineAllocation] that records the originating request index. The
  /// order-level [OrderAllocation] aggregates every produced [AllocationLine]
  /// and sets [OrderAllocation.isPartial] when ANY line is partial — the
  /// bounded heuristic is NOT claimed optimal (Requirement 8.12).
  ///
  /// Determinism: the method is a deterministic, repeatable composition of the
  /// per-request allocators (which are themselves deterministic), so identical
  /// [requests] + [availability] + [allow89ftFallback] always produce an
  /// identical result.
  ///
  /// The [availability] snapshot MUST contain at most one entry per
  /// `stockItemId` (asserted) so the per-item remaining balance is
  /// unambiguous; the caller builds it from the confirmed inventory (pending
  /// receiving stock is never sellable — Requirement 19.8). Each request's SKU
  /// constraints must be satisfiable by entries in [availability]; a request
  /// whose SKU is absent simply allocates nothing and is a fully-shorted
  /// partial.
  ///
  /// Architecture: headless — multi-line order allocation only; the Sell-tab
  /// picking-list UI is task 9.5.
  OrderAllocation allocateOrder(
    List<OrderRequest> requests,
    List<SkuAvailability> availability, {
    bool allow89ftFallback = false,
  }) {
    // The full snapshot must name each stock item at most once so the working
    // remaining-balance per item is unambiguous.
    final seenStockItems = <int>{};
    for (final a in availability) {
      if (!seenStockItems.add(a.stockItemId)) {
        throw ArgumentError(
          'duplicate stock item ${a.stockItemId} in the availability snapshot; '
          'multi-line allocation needs one remaining balance per stock item',
        );
      }
    }

    // Working copy of confirmed REMAINING pieces, keyed by stock item. Each
    // line decrements this so later lines only see what is left (no double
    // count — Requirements 8.6, 21.14; Property 10).
    final remainingPieces = <int, int>{
      for (final a in availability) a.stockItemId: a.availablePieces,
    };
    // Immutable per-item metadata (cross-section, length) used to rebuild the
    // remaining-availability views handed to the per-request allocators.
    final meta = <int, SkuAvailability>{
      for (final a in availability) a.stockItemId: a,
    };

    final lineResults = <OrderLineAllocation>[];
    final allLines = <AllocationLine>[];
    var anyPartial = false;

    for (var index = 0; index < requests.length; index++) {
      final request = requests[index];

      // Build the remaining-availability view for this request from the
      // CURRENT working copy, so earlier lines' consumption is already removed.
      SkuAvailability remainingFor(int stockItemId) {
        final m = meta[stockItemId]!;
        return SkuAvailability(
          stockItemId: m.stockItemId,
          crossSection: m.crossSection,
          lengthFt: m.lengthFt,
          availablePieces: remainingPieces[stockItemId]!,
        );
      }

      final List<AllocationLine> producedLines;
      final OrderLineAllocation lineResult;

      switch (request) {
        case ExactQtyRequest():
          // The pinned SKU: match variety + cross-section + length. Absent →
          // zero remaining so the allocator honestly shorts the whole demand.
          final sku = _findSku(
            meta,
            crossSectionId: request.crossSectionId,
            lengthFt: request.lengthFt,
          );
          final avail = sku == null
              ? SkuAvailability(
                  stockItemId: -1,
                  crossSection:
                      _mustResolveCrossSection(meta, request.crossSectionId),
                  lengthFt: request.lengthFt,
                  availablePieces: 0,
                )
              : remainingFor(sku);
          final line = allocateExact(request, avail);
          producedLines = <AllocationLine>[line];
          lineResult = OrderLineAllocation(
            requestIndex: index,
            kind: request.kind,
            lines: producedLines,
            isPartial: line.isPartial,
          );

        case TargetCftFixedLengthRequest():
          final sku = _findSku(
            meta,
            crossSectionId: request.crossSectionId,
            lengthFt: request.lengthFt,
          );
          final avail = sku == null
              ? SkuAvailability(
                  stockItemId: -1,
                  crossSection:
                      _mustResolveCrossSection(meta, request.crossSectionId),
                  lengthFt: request.lengthFt,
                  availablePieces: 0,
                )
              : remainingFor(sku);
          final line = allocateTargetCftFixedLength(request, avail);
          producedLines = <AllocationLine>[line];
          lineResult = OrderLineAllocation(
            requestIndex: index,
            kind: request.kind,
            lines: producedLines,
            isPartial: line.isPartial,
          );

        case TargetCftFlexCrossSectionRequest():
          // Every remaining entry for this cross-section (any length) with
          // pieces left is eligible; the flexible allocator picks lengths.
          final skuIds = _findSkusByCrossSection(
            meta,
            remainingPieces,
            crossSectionId: request.crossSectionId,
          );
          final views = <SkuAvailability>[
            for (final id in skuIds) remainingFor(id),
          ];
          final isReaper = _mustResolveCrossSection(
                meta,
                request.crossSectionId,
              ).category ==
              WoodCategory.reaper;
          if (isReaper) {
            final result = allocateFlexibleReaper(
              request,
              views,
              allow89ftFallback: allow89ftFallback,
            );
            producedLines = result.lines;
            lineResult = OrderLineAllocation(
              requestIndex: index,
              kind: request.kind,
              lines: producedLines,
              isPartial: result.isPartial,
              flexibleReaper: result,
            );
          } else {
            final result = allocateFlexiblePlank(request, views);
            producedLines = result.lines;
            lineResult = OrderLineAllocation(
              requestIndex: index,
              kind: request.kind,
              lines: producedLines,
              isPartial: result.isPartial,
              flexiblePlank: result,
            );
          }

        case TargetCftFlexCategoryRequest():
          // The category-flexible shape (task 9.x beyond 9.4) is not part of
          // the multi-line slice; reject rather than silently mis-allocate.
          throw UnsupportedError(
            'TargetCftFlexCategoryRequest is not supported by allocateOrder '
            '(task 9.4 covers the exact-qty, fixed-length, and flexible '
            'cross-section shapes)',
          );
      }

      // Subtract this line's consumption from the working copy so later lines
      // only see what remains — the heart of no-double-count (Property 10).
      for (final line in producedLines) {
        final id = line.stockItemId;
        if (id < 0 || line.allocatedPieces <= 0) {
          continue; // nothing drawn (absent SKU or empty line)
        }
        final left = remainingPieces[id];
        if (left == null) {
          continue;
        }
        remainingPieces[id] = left - line.allocatedPieces;
      }

      lineResults.add(lineResult);
      allLines.addAll(producedLines);
      anyPartial = anyPartial || lineResult.isPartial;
    }

    return OrderAllocation(
      lineResults: lineResults,
      lines: allLines,
      isPartial: anyPartial,
    );
  }

  /// Finds the single remaining stock item id matching [crossSectionId] +
  /// [lengthFt] (there is at most one per `stockItemId` by construction).
  /// Returns `null` when no such item exists in the snapshot.
  int? _findSku(
    Map<int, SkuAvailability> meta, {
    required int crossSectionId,
    required int lengthFt,
  }) {
    int? found;
    for (final entry in meta.entries) {
      final a = entry.value;
      if (a.crossSection.id == crossSectionId && a.lengthFt == lengthFt) {
        if (found == null || entry.key < found) {
          found = entry.key; // stable: lower stock-item id wins
        }
      }
    }
    return found;
  }

  /// All remaining stock item ids for a cross-section (any length) that still
  /// have pieces left, in stable lower-id order.
  List<int> _findSkusByCrossSection(
    Map<int, SkuAvailability> meta,
    Map<int, int> remainingPieces, {
    required int crossSectionId,
  }) {
    final ids = <int>[
      for (final entry in meta.entries)
        if (entry.value.crossSection.id == crossSectionId &&
            (remainingPieces[entry.key] ?? 0) > 0)
          entry.key,
    ]..sort();
    return ids;
  }

  /// Resolves the [CrossSection] for a pinned [crossSectionId] from the
  /// snapshot [meta]. Used to build an empty availability view when a request's
  /// SKU is absent so the per-request allocator can still produce an honest
  /// fully-shorted partial.
  CrossSection _mustResolveCrossSection(
    Map<int, SkuAvailability> meta,
    int crossSectionId,
  ) {
    for (final a in meta.values) {
      if (a.crossSection.id == crossSectionId) {
        return a.crossSection;
      }
    }
    throw ArgumentError(
      'cross-section $crossSectionId is not present in the availability '
      'snapshot; cannot allocate a line against unknown stock',
    );
  }

  /// Builds a [FlexiblePlankAllocation] from a per-length [pieceCountByLength]
  /// selection, one [AllocationLine] per used length (lower length first, then
  /// lower stock-item id), computing exact CFTs through the shared engine and
  /// labelling a partial with the exact CFT shortage when the allocated CFT is
  /// below the [target] (Requirements 8.4, 8.5).
  FlexiblePlankAllocation _buildPlankAllocation({
    required TargetCftFlexCrossSectionRequest request,
    required CrossSection crossSection,
    required Map<int, _PlankSlot> slots,
    required List<int> lengths,
    required Map<int, int> pieceCountByLength,
    required Rational target,
  }) {
    final usedLengths = lengths
        .where((len) => (pieceCountByLength[len] ?? 0) > 0)
        .toList()
      ..sort((a, b) {
        final byLen = a.compareTo(b);
        return byLen != 0
            ? byLen
            : slots[a]!.stockItemId.compareTo(slots[b]!.stockItemId);
      });

    final lines = <AllocationLine>[];
    var allocatedCft = Cft.zero;
    for (final len in usedLengths) {
      final pieces = pieceCountByLength[len]!;
      final slot = slots[len]!;
      final lineCft = _calc.lineCftFor(crossSection, len, pieces);
      allocatedCft += lineCft;
      lines.add(
        AllocationLine(
          stockItemId: slot.stockItemId,
          crossSectionId: crossSection.id,
          varietyId: request.varietyId,
          lengthFt: len,
          unit: AllocationUnit.piece,
          allocatedUnits: pieces,
          allocatedPieces: pieces,
          allocatedCft: lineCft,
          isPartial: false,
          shortageUnits: 0,
          shortagePieces: 0,
        ),
      );
    }

    final isPartial = allocatedCft.value < target;
    final shortageCft = isPartial ? Cft(target - allocatedCft.value) : Cft.zero;

    return FlexiblePlankAllocation(
      lines: lines,
      targetCft: Cft(target),
      allocatedCft: allocatedCft,
      isPartial: isPartial,
      shortageCft: shortageCft,
    );
  }

  /// Meet-or-exceed [groupTarget] CFT using whole bunches drawn from the given
  /// [lengths] (tried lower length first, then lower stock-item id), capped at
  /// each length's remaining availability. Mutates the matching [slots] and
  /// returns the exact CFT actually added by this call.
  ///
  /// Each length takes `ceil(remainingTarget / unitCft)` whole bunches, bounded
  /// by what is still available there, so the group meets-or-exceeds its target
  /// with the smallest preferred-length bunches first and never invents stock.
  Rational _fillTowards(
    List<int> lengths,
    Rational groupTarget,
    Map<int, _LengthSlot> slots,
  ) {
    if (groupTarget <= Rational.zero) {
      return Rational.zero;
    }
    // Candidate slots for this group, in the stable tie-break order.
    final candidates = <_LengthSlot>[
      for (final len in lengths)
        if (slots[len] != null) slots[len]!,
    ]..sort((a, b) {
        final byLen = a.lengthFt.compareTo(b.lengthFt);
        return byLen != 0 ? byLen : a.stockItemId.compareTo(b.stockItemId);
      });

    var remaining = groupTarget;
    var added = Rational.zero;
    for (final slot in candidates) {
      if (remaining <= Rational.zero) {
        break;
      }
      final free = slot.availableBunches - slot.allocatedBunches;
      if (free <= 0) {
        continue;
      }
      // Smallest whole-bunch count whose CFT meets-or-exceeds the remaining
      // target at this length, capped at the free bunches (exact BigInt ceil).
      final want = (remaining / slot.unitCft.value).ceil().toInt();
      final take = want < free ? want : free;
      if (take <= 0) {
        continue;
      }
      slot.allocatedBunches += take;
      final takenCft = slot.unitCft.value * Rational.fromInt(take);
      added += takenCft;
      remaining -= takenCft;
    }
    return added;
  }

  /// The exact total CFT currently allocated across all [slots].
  Rational _allocatedCft(Map<int, _LengthSlot> slots) {
    var total = Rational.zero;
    for (final slot in slots.values) {
      if (slot.allocatedBunches > 0) {
        total += slot.unitCft.value * Rational.fromInt(slot.allocatedBunches);
      }
    }
    return total;
  }
}

/// A reaper length group and its approximate share of the target CFT (CD-4).
class _ReaperGroup {
  const _ReaperGroup(this.lengths, this.share);

  /// The lengths (feet) that belong to this group, in preference order.
  final List<int> lengths;

  /// This group's approximate share of the overall target CFT.
  final Rational share;
}

/// Mutable per-length allocation state used by [AllocationService
/// .allocateFlexibleReaper]. One slot per eligible length that has stock.
class _LengthSlot {
  _LengthSlot({
    required this.lengthFt,
    required this.stockItemId,
    required this.crossSection,
    required this.unitCft,
    required this.availableBunches,
  });

  /// The piece length (feet) this slot allocates.
  final int lengthFt;

  /// The lowest stock-item id seen at this length (stable tie-breaker).
  int stockItemId;

  /// The (shared) reaper cross-section.
  final CrossSection crossSection;

  /// Exact CFT of one whole bunch at this length.
  final Cft unitCft;

  /// Whole bunches available (confirmed) at this length.
  int availableBunches;

  /// Whole bunches allocated so far at this length.
  int allocatedBunches = 0;
}

/// The result of a flexible-length reaper allocation (task 9.2).
///
/// Carries one [AllocationLine] per length actually used (lower length first),
/// the overall target and exact allocated CFT, and — when the eligible stock
/// could not meet or exceed the target even after redistribution — the partial
/// label plus the exact CFT shortage (Requirement 8.4). Every line is a whole
/// number of bunches (Requirement 8.8) and no 8/9 ft length appears unless the
/// fallback was enabled (Requirement 8.9).
@immutable
class FlexibleReaperAllocation {
  /// Creates a flexible-reaper allocation result.
  const FlexibleReaperAllocation({
    required this.lines,
    required this.targetCft,
    required this.allocatedCft,
    required this.isPartial,
    required this.shortageCft,
  });

  /// One line per length used, ordered lower length first then lower stock-item
  /// id. Empty when nothing could be allocated.
  final List<AllocationLine> lines;

  /// The requested target CFT.
  final Cft targetCft;

  /// The exact total allocated CFT (sum of the line CFTs). Billing uses this,
  /// never the target (Requirement 8.5).
  final Cft allocatedCft;

  /// Whether this is a clearly-labelled **partial** — the eligible stock could
  /// not meet or exceed the target (Requirement 8.4). `false` means the target
  /// was met or exceeded.
  final bool isPartial;

  /// The exact CFT shortfall (`target − allocated`) when [isPartial];
  /// [Cft.zero] when the target was met or exceeded.
  final Cft shortageCft;

  /// Whether the target was met or exceeded (the inverse of [isPartial]).
  bool get isFullyAllocated => !isPartial;

  @override
  String toString() =>
      'FlexibleReaperAllocation(lines: ${lines.length}, '
      'targetCft: ${targetCft.toFixed()}, '
      'allocatedCft: ${allocatedCft.toFixed()}, isPartial: $isPartial, '
      'shortageCft: ${shortageCft.toFixed()})';
}

/// Mutable per-length allocation state used by [AllocationService
/// .allocateFlexiblePlank]. One slot per plank length that has stock; planks
/// count in whole pieces (bunch size 1), so capacity is the available pieces.
class _PlankSlot {
  _PlankSlot({
    required this.lengthFt,
    required this.stockItemId,
    required this.availablePieces,
  });

  /// The piece length (feet) this slot allocates.
  final int lengthFt;

  /// The lowest stock-item id seen at this length (stable tie-breaker).
  int stockItemId;

  /// Whole pieces available (confirmed) at this length.
  int availablePieces;
}

/// The result of a flexible-length plank allocation (task 9.3).
///
/// Carries one [AllocationLine] per length actually used (lower length first,
/// then lower stock-item id), the overall target and exact allocated CFT, and —
/// when the eligible plank stock could not meet or exceed the target even using
/// every available piece — the partial label plus the exact CFT shortage
/// (Requirement 8.4). Every line is a whole number of pieces (Requirement 8.11)
/// and the reaper 60/30/10 length-group shares are never applied (Requirement
/// 8.10). Mirrors [FlexibleReaperAllocation] so the Sell-tab review (task 9.5)
/// can treat the two flexible results uniformly.
@immutable
class FlexiblePlankAllocation {
  /// Creates a flexible-plank allocation result.
  const FlexiblePlankAllocation({
    required this.lines,
    required this.targetCft,
    required this.allocatedCft,
    required this.isPartial,
    required this.shortageCft,
  });

  /// One line per length used, ordered lower length first then lower stock-item
  /// id. Empty when nothing could be allocated.
  final List<AllocationLine> lines;

  /// The requested target CFT.
  final Cft targetCft;

  /// The exact total allocated CFT (sum of the line CFTs). Billing uses this,
  /// never the target (Requirement 8.5).
  final Cft allocatedCft;

  /// Whether this is a clearly-labelled **partial** — the eligible stock could
  /// not meet or exceed the target (Requirement 8.4). `false` means the target
  /// was met or exceeded.
  final bool isPartial;

  /// The exact CFT shortfall (`target − allocated`) when [isPartial];
  /// [Cft.zero] when the target was met or exceeded.
  final Cft shortageCft;

  /// Whether the target was met or exceeded (the inverse of [isPartial]).
  bool get isFullyAllocated => !isPartial;

  @override
  String toString() =>
      'FlexiblePlankAllocation(lines: ${lines.length}, '
      'targetCft: ${targetCft.toFixed()}, '
      'allocatedCft: ${allocatedCft.toFixed()}, isPartial: $isPartial, '
      'shortageCft: ${shortageCft.toFixed()})';
}

/// One line's result within a multi-line order allocation (task 9.4).
///
/// Wraps the per-request allocation produced by [AllocationService
/// .allocateOrder] with the originating [requestIndex] and [kind], preserving
/// each line's own partial/shortage labelling (Requirements 8.3, 8.4). The
/// concrete per-line [lines] are always present; for the flexible shapes the
/// richer [flexibleReaper] / [flexiblePlank] summary (carrying the exact CFT
/// shortage) is also attached so the Sell-tab review (task 9.5) can show the
/// target-vs-allocated gap without recomputing it.
@immutable
class OrderLineAllocation {
  /// Creates a per-line order allocation result.
  const OrderLineAllocation({
    required this.requestIndex,
    required this.kind,
    required this.lines,
    required this.isPartial,
    this.flexibleReaper,
    this.flexiblePlank,
  });

  /// The 0-based index of the originating request in the order's request list.
  final int requestIndex;

  /// Which of the four structured shapes produced this line.
  final OrderRequestKind kind;

  /// The allocation lines produced for this request against the REMAINING
  /// availability at the time it was allocated. One entry for the exact and
  /// fixed-length shapes; one per used length for the flexible shapes. Empty
  /// when nothing could be allocated.
  final List<AllocationLine> lines;

  /// Whether this line is a clearly-labelled **partial** — the remaining stock
  /// could not cover its demand (Requirements 8.3, 8.4). A later line commonly
  /// goes partial because an earlier line consumed the stock it needed
  /// (Requirement 21.14).
  final bool isPartial;

  /// The flexible-reaper summary when [kind] is
  /// [OrderRequestKind.targetCftFlexCrossSection] for a reaper cross-section;
  /// otherwise `null`.
  final FlexibleReaperAllocation? flexibleReaper;

  /// The flexible-plank summary when [kind] is
  /// [OrderRequestKind.targetCftFlexCrossSection] for a plank cross-section;
  /// otherwise `null`.
  final FlexiblePlankAllocation? flexiblePlank;

  /// Whether this line's demand was satisfied in full (the inverse of
  /// [isPartial]).
  bool get isFullyAllocated => !isPartial;

  @override
  String toString() =>
      'OrderLineAllocation(requestIndex: $requestIndex, kind: ${kind.name}, '
      'lines: ${lines.length}, isPartial: $isPartial)';
}

/// The order-level result of a multi-line allocation (task 9.4; Requirements
/// 8.4, 8.6, 8.12; Correctness Property 10).
///
/// Aggregates every [AllocationLine] produced across the order's request lines
/// (allocated in order against the remaining availability, so no stock quantity
/// is counted twice — Requirements 8.6, 21.14) together with the per-line
/// [lineResults]. [isPartial] is set when ANY line is a partial; the whole
/// proposal is then clearly a partial and is never presented as fulfilled
/// (Requirement 8.4). The underlying heuristic is bounded and NOT claimed
/// optimal (Requirement 8.12).
@immutable
class OrderAllocation {
  /// Creates an order-level allocation result.
  const OrderAllocation({
    required this.lineResults,
    required this.lines,
    required this.isPartial,
  });

  /// Per-request results, in the order the requests were supplied.
  final List<OrderLineAllocation> lineResults;

  /// Every allocation line produced across all request lines (flattened), in
  /// request order then line order. Billing/picking consumes this list.
  final List<AllocationLine> lines;

  /// Whether the order is a clearly-labelled **partial** — true when any line
  /// could not be fully satisfied from the remaining stock (Requirement 8.4).
  final bool isPartial;

  /// Whether every line in the order was satisfied in full (the inverse of
  /// [isPartial]).
  bool get isFullyAllocated => !isPartial;

  @override
  String toString() =>
      'OrderAllocation(lineResults: ${lineResults.length}, '
      'lines: ${lines.length}, isPartial: $isPartial)';
}
