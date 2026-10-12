/// A staged target-CFT request on the order-build surface (app-ux-revamp
/// Requirement 3, 7.3-7.5).
///
/// Unlike an adjustable exact-quantity line (`StagedOrderLine`), a target
/// request does NOT carry a whole-unit quantity the owner tunes with a +/-
/// stepper: the allocator decides how many units meet-or-exceed the requested
/// CFT. A staged target therefore pins only the structured constraints the
/// owner chose — a variety, optionally a cross-section OR a category, optionally
/// a fixed length — plus the exact target CFT (a `Rational`, never a double, so
/// the request round-trips without drift).
///
/// It maps directly to one of the three target-CFT `OrderRequest` subtypes via
/// [toRequest]:
///
///   * fixed length + cross-section  -> `TargetCftFixedLengthRequest`;
///   * cross-section, flexible length -> `TargetCftFlexCrossSectionRequest`;
///   * category only, flexible         -> `TargetCftFlexCategoryRequest`.
library;

import 'package:meta/meta.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/order_request.dart';

/// Which of the three target-CFT shapes a staged target request represents.
enum StagedTargetKind {
  /// Target CFT pinned to a cross-section and an exact length (Req 7.3).
  fixedLength,

  /// Target CFT pinned to a cross-section, lengths flexible (Req 7.4).
  flexCrossSection,

  /// Target CFT within a category, cross-section and lengths flexible (Req 7.5).
  flexCategory,
}

/// One staged target-CFT request in the order-build surface.
@immutable
class StagedTargetRequest {
  /// Creates a staged target request. The caller must supply the fields the
  /// [kind] constrains ([crossSection] for the two cross-section shapes,
  /// [category] for the category shape, [lengthFt] for the fixed-length shape).
  const StagedTargetRequest({
    required this.kind,
    required this.varietyId,
    required this.varietyName,
    required this.targetCft,
    this.crossSection,
    this.category,
    this.lengthFt,
  });

  /// Which target shape this request is.
  final StagedTargetKind kind;

  /// The owning variety id.
  final int varietyId;

  /// The variety display name (shown on the line).
  final String varietyName;

  /// The exact target CFT to meet or exceed (strictly positive).
  final Rational targetCft;

  /// The pinned cross-section (present for the two cross-section shapes).
  final CrossSection? crossSection;

  /// The pinned category (present for the category shape).
  final WoodCategory? category;

  /// The pinned length in feet (present for the fixed-length shape).
  final int? lengthFt;

  /// A short, unit-labelled summary shown on the staged list.
  String get summaryLabel {
    final cft = '${targetCft.toDouble().toStringAsFixed(4)} CFT';
    return switch (kind) {
      StagedTargetKind.fixedLength =>
        '$varietyName · ${crossSection?.inchLabel ?? '?'} · '
            '${lengthFt ?? '?'} ft · ≥ $cft',
      StagedTargetKind.flexCrossSection =>
        '$varietyName · ${crossSection?.inchLabel ?? '?'} · '
            'flexible lengths · ≥ $cft',
      StagedTargetKind.flexCategory =>
        '$varietyName · ${category?.name ?? '?'} · flexible · ≥ $cft',
    };
  }

  /// Maps this staged target to the structured [OrderRequest] the allocation
  /// engine consumes.
  OrderRequest toRequest() {
    switch (kind) {
      case StagedTargetKind.fixedLength:
        return TargetCftFixedLengthRequest(
          varietyId: varietyId,
          crossSectionId: crossSection!.id,
          lengthFt: lengthFt!,
          targetCft: targetCft,
        );
      case StagedTargetKind.flexCrossSection:
        return TargetCftFlexCrossSectionRequest(
          varietyId: varietyId,
          crossSectionId: crossSection!.id,
          targetCft: targetCft,
        );
      case StagedTargetKind.flexCategory:
        return TargetCftFlexCategoryRequest(
          varietyId: varietyId,
          category: category!,
          targetCft: targetCft,
        );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StagedTargetRequest &&
          other.kind == kind &&
          other.varietyId == varietyId &&
          other.targetCft == targetCft &&
          other.crossSection?.id == crossSection?.id &&
          other.category == category &&
          other.lengthFt == lengthFt);

  @override
  int get hashCode => Object.hash(
        kind,
        varietyId,
        targetCft,
        crossSection?.id,
        category,
        lengthFt,
      );

  @override
  String toString() => 'StagedTargetRequest(${kind.name}, $summaryLabel)';
}
