/// A staged, adjustable order line (app-ux-revamp Requirement 3).
///
/// A staged line pins a concrete SKU — a variety, a `CrossSection`, and a
/// length — plus a whole-unit `quantityUnits` the owner can increase or
/// decrease in place (bunches for a reaper, pieces for a plank). Its exact CFT
/// is derived from the single shared `CalculationService`, never stored as a
/// double, so the displayed volume can never drift (Requirement 3.1, 3.3;
/// inherits Correctness Properties 1-4).
library;

import 'package:meta/meta.dart';

import 'package:wood_cft/domain/catalog.dart';

/// One adjustable staged line in the order-build surface.
@immutable
class StagedOrderLine {
  /// Creates a staged line for [quantityUnits] whole units of the SKU
  /// described by [varietyId] + [crossSection] + [lengthFt].
  const StagedOrderLine({
    required this.varietyId,
    required this.varietyName,
    required this.crossSection,
    required this.lengthFt,
    required this.quantityUnits,
  });

  /// The owning variety id.
  final int varietyId;

  /// The variety display name (shown on the line).
  final String varietyName;

  /// The pinned cross-section (carries category + bunch size).
  final CrossSection crossSection;

  /// The piece length in feet.
  final int lengthFt;

  /// The whole-unit count: bunches for a reaper, pieces for a plank. Always
  /// strictly positive for a line that exists; decrement-to-zero removes it.
  final int quantityUnits;

  /// Whether this line's cross-section is a reaper (sold in bunches of 10).
  bool get isReaper => crossSection.category == WoodCategory.reaper;

  /// The unit word for this line ("bunches" or "pcs").
  String get unitLabel => isReaper ? 'bunches' : 'pcs';

  /// The piece-equivalent of [quantityUnits] (units x bunch size).
  int get pieces => quantityUnits * crossSection.bunchSize;

  /// A stable identity for this SKU (variety + cross-section + length). Two
  /// lines with the same key are the same SKU and are merged.
  String get skuKey => '$varietyId:${crossSection.id}:$lengthFt';

  /// Returns a copy of this line with [quantityUnits] replaced.
  StagedOrderLine withQuantity(int quantityUnits) => StagedOrderLine(
        varietyId: varietyId,
        varietyName: varietyName,
        crossSection: crossSection,
        lengthFt: lengthFt,
        quantityUnits: quantityUnits,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StagedOrderLine &&
          other.varietyId == varietyId &&
          other.crossSection.id == crossSection.id &&
          other.lengthFt == lengthFt &&
          other.quantityUnits == quantityUnits);

  @override
  int get hashCode =>
      Object.hash(varietyId, crossSection.id, lengthFt, quantityUnits);

  @override
  String toString() =>
      'StagedOrderLine($varietyName, ${crossSection.inchLabel}, '
      '$lengthFt ft, $quantityUnits $unitLabel)';
}
