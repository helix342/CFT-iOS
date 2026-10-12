/// Pure-Dart structured order-request domain models (task 8.1).
///
/// Requirement 7.1 fixes order entry to **structured entry only** — there is no
/// natural-language or AI interpretation anywhere in this layer. The owner
/// chooses one of exactly FOUR request shapes (design.md -> Screen Flows ->
/// Sell tab; Data Models -> DraftOrderRequest):
///
///   1. [ExactQtyRequest]              — exact quantity of one specific SKU
///      (Requirement 7.2);
///   2. [TargetCftFixedLengthRequest]  — target CFT at an exact length
///      (Requirement 7.3);
///   3. [TargetCftFlexCrossSectionRequest] — target CFT, fixed cross-section,
///      flexible lengths (Requirement 7.4);
///   4. [TargetCftFlexCategoryRequest] — target CFT within a category,
///      flexible lengths (Requirement 7.5).
///
/// These are **value objects**: identity + the structured constraints only.
/// They validate their own shape (so an impossible request can never be
/// constructed) but hold NO allocation logic — allocation is the application
/// layer's job. Only exact-quantity allocation ships in task 8.1
/// ([OrderRequestKind.exactQty]); the three target-CFT shapes are defined here
/// so the Sell-tab entry (task 8.2) and the constrained heuristic (task 9.x)
/// have a stable domain to build on.
///
/// Unit discipline mirrors the catalog: a reaper trades in whole BUNCHES of 10
/// pieces, a plank in whole PIECES (Requirements 3.1, 3.3). An exact-quantity
/// request therefore carries its quantity in **whole sale units** (bunches for
/// a reaper, pieces for a plank) and the caller resolves the piece-equivalent
/// through `CalculationService` / [CrossSection.bunchSize].
///
/// Architecture rule (design.md): the domain layer has a strict inward
/// dependency direction and MUST NOT import `package:flutter/*` or `dart:io`.
library;

import 'package:meta/meta.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/domain/catalog.dart';

/// The four structured request shapes (Requirement 7.2–7.5).
///
/// Mirrors the data-layer `RequestType` enum; kept as an independent domain
/// enum so the domain owns its own closed set (design.md -> DraftOrderRequest).
enum OrderRequestKind {
  /// Exact quantity of one specific SKU (Requirement 7.2).
  exactQty,

  /// Target CFT at an exact, fixed length (Requirement 7.3).
  targetCftFixedLength,

  /// Target CFT, fixed cross-section, flexible lengths (Requirement 7.4).
  targetCftFlexCrossSection,

  /// Target CFT within a category, flexible lengths (Requirement 7.5).
  targetCftFlexCategory,
}

/// Base type for the four structured order requests.
///
/// Every request names the target [varietyId] and declares its [kind]. The
/// structured constraints (cross-section, category, length, target CFT, exact
/// quantity) live on the concrete subtypes so each shape only exposes the
/// fields it actually constrains.
@immutable
sealed class OrderRequest {
  const OrderRequest({required this.varietyId});

  /// Which of the four structured shapes this request is.
  OrderRequestKind get kind;

  /// The target wood variety (always required for every shape).
  final int varietyId;
}

/// A request for an exact quantity of one specific stock item (Requirement
/// 7.2).
///
/// The SKU is fully pinned: [varietyId] + [crossSectionId] + [lengthFt]
/// identify a single stock item, and [quantityUnits] is the number of **whole
/// sale units** demanded — bunches for a reaper, pieces for a plank. No target
/// CFT is involved; the quantity is literal.
///
/// Validation (so an impossible request can never exist):
///   * [quantityUnits] must be strictly positive;
///   * [lengthFt] must be within the 2–9 ft stock range (Requirement 1.10).
///
/// The whole-unit hard constraint for reapers (quantity expressed in bunches)
/// is naturally satisfied because [quantityUnits] already counts whole units;
/// the piece-equivalent (× bunch size) is resolved by the allocation service.
@immutable
final class ExactQtyRequest extends OrderRequest {
  /// Creates an exact-quantity request for a single pinned SKU.
  ExactQtyRequest({
    required super.varietyId,
    required this.crossSectionId,
    required this.lengthFt,
    required this.quantityUnits,
  }) {
    if (quantityUnits <= 0) {
      throw ArgumentError.value(
        quantityUnits,
        'quantityUnits',
        'exact-quantity request must demand a positive whole-unit quantity',
      );
    }
    if (lengthFt < kMinLengthFt || lengthFt > kMaxLengthFt) {
      throw RangeError.range(
        lengthFt,
        kMinLengthFt,
        kMaxLengthFt,
        'lengthFt',
        'length (feet) must be within $kMinLengthFt–$kMaxLengthFt inclusive',
      );
    }
  }

  @override
  OrderRequestKind get kind => OrderRequestKind.exactQty;

  /// The pinned cross-section.
  final int crossSectionId;

  /// The pinned piece length in feet (2–9 inclusive).
  final int lengthFt;

  /// The demanded quantity in **whole sale units** (bunches for a reaper,
  /// pieces for a plank). Always positive.
  final int quantityUnits;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExactQtyRequest &&
          varietyId == other.varietyId &&
          crossSectionId == other.crossSectionId &&
          lengthFt == other.lengthFt &&
          quantityUnits == other.quantityUnits);

  @override
  int get hashCode =>
      Object.hash(kind, varietyId, crossSectionId, lengthFt, quantityUnits);

  @override
  String toString() =>
      'ExactQtyRequest(varietyId: $varietyId, crossSectionId: $crossSectionId, '
      'lengthFt: $lengthFt, quantityUnits: $quantityUnits)';
}

/// A request for a target CFT at one exact, fixed length (Requirement 7.3).
///
/// The cross-section and length are pinned; the quantity is derived later by
/// the meet-or-exceed heuristic (task 9.x) — this value object only carries the
/// structured constraint. A fixed-length request that cannot be met must never
/// silently mix other lengths (Requirement 8-21.12), a rule the allocator
/// enforces; here the length is simply fixed.
///
/// Validation: [targetCft] must be strictly positive; [lengthFt] must be in the
/// 2–9 ft range.
@immutable
final class TargetCftFixedLengthRequest extends OrderRequest {
  /// Creates a target-CFT request pinned to a cross-section and length.
  TargetCftFixedLengthRequest({
    required super.varietyId,
    required this.crossSectionId,
    required this.lengthFt,
    required this.targetCft,
  }) {
    _checkPositiveTarget(targetCft);
    if (lengthFt < kMinLengthFt || lengthFt > kMaxLengthFt) {
      throw RangeError.range(
        lengthFt,
        kMinLengthFt,
        kMaxLengthFt,
        'lengthFt',
        'length (feet) must be within $kMinLengthFt–$kMaxLengthFt inclusive',
      );
    }
  }

  @override
  OrderRequestKind get kind => OrderRequestKind.targetCftFixedLength;

  /// The pinned cross-section.
  final int crossSectionId;

  /// The pinned piece length in feet (2–9 inclusive).
  final int lengthFt;

  /// The target CFT to meet or exceed (exact rational, strictly positive).
  final Rational targetCft;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TargetCftFixedLengthRequest &&
          varietyId == other.varietyId &&
          crossSectionId == other.crossSectionId &&
          lengthFt == other.lengthFt &&
          targetCft == other.targetCft);

  @override
  int get hashCode =>
      Object.hash(kind, varietyId, crossSectionId, lengthFt, targetCft);

  @override
  String toString() =>
      'TargetCftFixedLengthRequest(varietyId: $varietyId, '
      'crossSectionId: $crossSectionId, lengthFt: $lengthFt, '
      'targetCft: $targetCft)';
}

/// A request for a target CFT with a fixed cross-section but flexible lengths
/// (Requirement 7.4).
///
/// The cross-section is pinned; the allocator (task 9.x) is free to choose
/// lengths subject to the flexible-length rules. No length is carried here.
///
/// Validation: [targetCft] must be strictly positive.
@immutable
final class TargetCftFlexCrossSectionRequest extends OrderRequest {
  /// Creates a target-CFT request pinned to a cross-section, lengths flexible.
  TargetCftFlexCrossSectionRequest({
    required super.varietyId,
    required this.crossSectionId,
    required this.targetCft,
  }) {
    _checkPositiveTarget(targetCft);
  }

  @override
  OrderRequestKind get kind => OrderRequestKind.targetCftFlexCrossSection;

  /// The pinned cross-section (lengths are flexible).
  final int crossSectionId;

  /// The target CFT to meet or exceed (exact rational, strictly positive).
  final Rational targetCft;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TargetCftFlexCrossSectionRequest &&
          varietyId == other.varietyId &&
          crossSectionId == other.crossSectionId &&
          targetCft == other.targetCft);

  @override
  int get hashCode => Object.hash(kind, varietyId, crossSectionId, targetCft);

  @override
  String toString() =>
      'TargetCftFlexCrossSectionRequest(varietyId: $varietyId, '
      'crossSectionId: $crossSectionId, targetCft: $targetCft)';
}

/// A request for a target CFT within a category, with flexible lengths
/// (Requirement 7.5).
///
/// Only the [category] (reaper or plank) is pinned; the allocator chooses
/// cross-sections and lengths within that category. No cross-section or length
/// is carried here.
///
/// Validation: [targetCft] must be strictly positive.
@immutable
final class TargetCftFlexCategoryRequest extends OrderRequest {
  /// Creates a target-CFT request constrained only by category.
  TargetCftFlexCategoryRequest({
    required super.varietyId,
    required this.category,
    required this.targetCft,
  }) {
    _checkPositiveTarget(targetCft);
  }

  @override
  OrderRequestKind get kind => OrderRequestKind.targetCftFlexCategory;

  /// The pinned category (reaper or plank); cross-section and length flexible.
  final WoodCategory category;

  /// The target CFT to meet or exceed (exact rational, strictly positive).
  final Rational targetCft;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TargetCftFlexCategoryRequest &&
          varietyId == other.varietyId &&
          category == other.category &&
          targetCft == other.targetCft);

  @override
  int get hashCode => Object.hash(kind, varietyId, category, targetCft);

  @override
  String toString() =>
      'TargetCftFlexCategoryRequest(varietyId: $varietyId, '
      'category: ${category.name}, targetCft: $targetCft)';
}

/// Shared validation: a target CFT must be a strictly positive rational.
void _checkPositiveTarget(Rational targetCft) {
  if (targetCft <= Rational.zero) {
    throw ArgumentError.value(
      targetCft,
      'targetCft',
      'target CFT must be strictly positive',
    );
  }
}
