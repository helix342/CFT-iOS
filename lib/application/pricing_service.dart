/// The price-matrix service: rate lookups, scaffolding, and missing-rate
/// detection (task 7.1).
///
/// `PricingService` is the headless application-layer facade over the price
/// matrix (design.md -> Components and Interfaces: "`PricingService` — price
/// matrix lookups, missing-rate detection"). It wraps the data-layer
/// `PriceRateRepository` and exposes the price behaviour the rest of the app
/// depends on:
///
///   * `rateFor` — look up the exact ₹/CFT rate for a variety × cross-section;
///     returns `null` when the rate is MISSING. Length is NEVER a parameter
///     (Req 4.2; CD-2).
///   * `onVarietyAdded` — scaffold EMPTY (null) rate cells for a newly added
///     variety across the catalog's cross-sections, never inferring a value
///     (Req 4.4).
///   * `setRate` / `clearRate` — set or clear a cell's exact rational rate
///     (Req 4.1).
///   * `missingRates` — report every unpriced (variety, cross-section) pair
///     (Req 4.5).
///
/// A rate is INR per CFT, GST-exclusive (Req 4.1), stored as an exact
/// `Rational` (never a binary `double`). This service holds no price logic that
/// depends on length, by construction: it has no length-bearing API.
///
/// Architecture: this layer orchestrates the data layer and holds no UI. The
/// editable price-matrix grid (with its visible missing-rate markers) is
/// task 7.2.
library;

import 'package:meta/meta.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/data/price_rate_repository.dart';

/// An unpriced price-matrix pair: a (variety, cross-section) key with no rate.
///
/// Length is intentionally absent — rates are keyed by variety × cross-section
/// only (Req 4.2). The presence of a [MissingRate] means [PricingService]
/// cannot price any sold line for that pair, which later blocks finalization
/// (Req 4.7, enforced in the billing/finalize tasks).
@immutable
class MissingRate {
  /// Creates a missing-rate marker for [varietyId] × [crossSectionId].
  const MissingRate({
    required this.varietyId,
    required this.crossSectionId,
  });

  /// The variety whose rate is missing.
  final int varietyId;

  /// The cross-section whose rate is missing.
  final int crossSectionId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MissingRate &&
          varietyId == other.varietyId &&
          crossSectionId == other.crossSectionId);

  @override
  int get hashCode => Object.hash(varietyId, crossSectionId);

  @override
  String toString() =>
      'MissingRate(varietyId: $varietyId, crossSectionId: $crossSectionId)';
}

/// Headless price-matrix service over a [PriceRateRepository].
class PricingService {
  /// Creates a pricing service backed by [_repository].
  PricingService(this._repository);

  final PriceRateRepository _repository;

  /// Returns the exact ₹/CFT rate for [varietyId] × [crossSectionId], or `null`
  /// when the rate is missing.
  ///
  /// This is the authoritative price lookup used by order entry and billing.
  /// It takes NO length argument: the rate depends on variety and cross-section
  /// only, so the same rate is returned for every length (Req 4.2; CD-2).
  Future<Rational?> rateFor({
    required int varietyId,
    required int crossSectionId,
  }) {
    return _repository.lookupRate(
      varietyId: varietyId,
      crossSectionId: crossSectionId,
    );
  }

  /// Returns `true` when [varietyId] × [crossSectionId] has a valid rate.
  Future<bool> hasRate({
    required int varietyId,
    required int crossSectionId,
  }) async {
    final rate = await rateFor(
      varietyId: varietyId,
      crossSectionId: crossSectionId,
    );
    return rate != null;
  }

  /// Scaffolds EMPTY (missing) rate cells for a newly added [varietyId] across
  /// [crossSectionIds], returning the number of cells created.
  ///
  /// Called when a variety is added (Req 4.4): the new variety appears as a row
  /// in the price matrix with every cell MISSING. No rate is inferred or copied
  /// from another variety; the owner must enter each one explicitly. Cells that
  /// already exist (e.g. on a re-run) are left untouched.
  Future<int> onVarietyAdded({
    required int varietyId,
    required Iterable<int> crossSectionIds,
  }) {
    return _repository.scaffoldEmptyRates(
      varietyId: varietyId,
      crossSectionIds: crossSectionIds,
    );
  }

  /// Sets the exact ₹/CFT [rate] for [varietyId] × [crossSectionId] (Req 4.1).
  ///
  /// Length is never involved (Req 4.2). Throws an [ArgumentError] when [rate]
  /// is not strictly positive.
  Future<void> setRate({
    required int varietyId,
    required int crossSectionId,
    required Rational rate,
  }) {
    return _repository.setRate(
      varietyId: varietyId,
      crossSectionId: crossSectionId,
      rate: rate,
    );
  }

  /// Clears the rate for [varietyId] × [crossSectionId], marking it MISSING.
  Future<void> clearRate({
    required int varietyId,
    required int crossSectionId,
  }) {
    return _repository.clearRate(
      varietyId: varietyId,
      crossSectionId: crossSectionId,
    );
  }

  /// Returns every unpriced (variety, cross-section) pair in the matrix — the
  /// exact set of missing rates (Req 4.5).
  Future<List<MissingRate>> missingRates() async {
    final cells = await _repository.missingCells();
    return cells
        .map((c) => MissingRate(
              varietyId: c.varietyId,
              crossSectionId: c.crossSectionId,
            ))
        .toList(growable: false);
  }
}
