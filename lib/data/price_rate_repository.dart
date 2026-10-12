/// Persistence for the price matrix: one exact ₹/CFT rate per
/// variety × cross-section (task 7.1).
///
/// [PriceRateRepository] is the data-layer entry point for the `PriceRates`
/// table (design.md -> Data Models, PriceRate: unique(`variety_id`,
/// `cross_section_id`)). It owns the storage shape of a rate and the two
/// invariants that make the price matrix honest:
///
///   * **Length independence (Req 4.2; CD-2).** A rate is keyed by variety ×
///     cross-section ONLY. There is no length column on `PriceRates`, so a rate
///     physically cannot vary by `length_ft` — the same stored rate is used for
///     every length of a given variety × cross-section.
///   * **Never guessed (Req 4.4).** Scaffolding a variety creates rows whose
///     `rate_num`/`rate_den` are BOTH null (a *missing* rate). A null rate is
///     never replaced with an inferred or default value — only an explicit
///     `setRate` gives a row a value.
///
/// Value representation (design.md -> CFT and Currency Arithmetic): a rate is an
/// exact rational ₹/CFT, GST-exclusive (Req 4.1). It is persisted as the
/// integer numerator/denominator pair `rate_num`/`rate_den` and reconstituted
/// as a [Rational]; it is NEVER stored as a binary `double`. A row with both
/// columns null means the rate is MISSING; a row with both set is a valid rate.
///
/// This is strictly the data layer: it reads and writes `PriceRates` rows and
/// does not own the missing-rate *policy* surfaced to selling/finalize — that
/// orchestration lives in `PricingService` (lib/application), and the editable
/// grid UI is task 7.2.
library;

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/data/app_database.dart';

/// A single price-matrix cell: the (variety, cross-section) key and its rate.
///
/// [rate] is `null` when the cell is a *missing* rate (both `rate_num` and
/// `rate_den` null in storage). Length is deliberately absent — a cell is keyed
/// by variety × cross-section only (Req 4.2).
@immutable
class PriceCell {
  /// Creates a price cell for [varietyId] × [crossSectionId] with [rate].
  const PriceCell({
    required this.varietyId,
    required this.crossSectionId,
    required this.rate,
  });

  /// The owning variety id (part of the business key).
  final int varietyId;

  /// The owning cross-section id (part of the business key).
  final int crossSectionId;

  /// The exact ₹/CFT rate, or `null` when the rate is missing.
  final Rational? rate;

  /// Whether this cell has no valid rate (Req 4.5).
  bool get isMissing => rate == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PriceCell &&
          varietyId == other.varietyId &&
          crossSectionId == other.crossSectionId &&
          rate == other.rate);

  @override
  int get hashCode => Object.hash(varietyId, crossSectionId, rate);

  @override
  String toString() =>
      'PriceCell(varietyId: $varietyId, crossSectionId: $crossSectionId, '
      'rate: ${rate ?? 'missing'})';
}

/// Reads and writes the `PriceRates` table, keyed by variety × cross-section.
class PriceRateRepository {
  /// Creates a repository backed by [_db].
  PriceRateRepository(this._db);

  final AppDatabase _db;

  /// Ensures an (empty) rate row exists for every [crossSectionIds] under
  /// [varietyId], creating any that are missing with a NULL (missing) rate.
  ///
  /// This is the scaffolding step run when a variety is added (Req 4.4): it
  /// materialises the variety's row in the price matrix across the given
  /// cross-sections without ever inferring a value. Existing rows (whether
  /// missing or already priced) are left UNTOUCHED, so re-scaffolding never
  /// clears a rate the owner already entered. Returns the number of rows
  /// created.
  Future<int> scaffoldEmptyRates({
    required int varietyId,
    required Iterable<int> crossSectionIds,
  }) async {
    return _db.transaction(() async {
      final existing = await (_db.select(_db.priceRates)
            ..where((r) => r.varietyId.equals(varietyId)))
          .get();
      final have = existing.map((r) => r.crossSectionId).toSet();

      var created = 0;
      for (final crossSectionId in crossSectionIds) {
        if (have.contains(crossSectionId)) {
          continue;
        }
        await _db.into(_db.priceRates).insert(
              PriceRatesCompanion.insert(
                varietyId: varietyId,
                crossSectionId: crossSectionId,
                // Both null = missing rate; never inferred (Req 4.4).
                rateNum: const Value(null),
                rateDen: const Value(null),
              ),
            );
        created++;
      }
      return created;
    });
  }

  /// Sets the exact ₹/CFT [rate] for [varietyId] × [crossSectionId].
  ///
  /// The rate is stored as the numerator/denominator pair of its reduced
  /// [Rational] form, so reading it back yields the exact same value (Req 4.1).
  /// Length is never a parameter (Req 4.2). The row is created if it does not
  /// yet exist and updated in place otherwise (upsert on the unique
  /// variety × cross-section key).
  ///
  /// Throws an [ArgumentError] when [rate] is not strictly positive — a price
  /// of zero or less is never a valid ₹/CFT rate.
  Future<void> setRate({
    required int varietyId,
    required int crossSectionId,
    required Rational rate,
  }) async {
    if (rate <= Rational.zero) {
      throw ArgumentError.value(
        rate,
        'rate',
        'a ₹/CFT rate must be strictly positive',
      );
    }
    await _upsert(
      varietyId: varietyId,
      crossSectionId: crossSectionId,
      rateNum: rate.numerator,
      rateDen: rate.denominator,
    );
  }

  /// Clears the rate for [varietyId] × [crossSectionId], marking it MISSING.
  ///
  /// The row is retained (so the cell still appears in the matrix) but its
  /// `rate_num`/`rate_den` become null, which [lookupRate] reports as a missing
  /// rate (Req 4.5). The row is created (as missing) if it did not exist.
  Future<void> clearRate({
    required int varietyId,
    required int crossSectionId,
  }) async {
    await _upsert(
      varietyId: varietyId,
      crossSectionId: crossSectionId,
      rateNum: null,
      rateDen: null,
    );
  }

  /// Returns the exact ₹/CFT rate for [varietyId] × [crossSectionId], or `null`
  /// when the rate is missing or no row exists.
  ///
  /// Length is intentionally NOT a parameter: the same rate applies to every
  /// length of a given variety × cross-section (Req 4.2).
  Future<Rational?> lookupRate({
    required int varietyId,
    required int crossSectionId,
  }) async {
    final row = await (_db.select(_db.priceRates)
          ..where((r) =>
              r.varietyId.equals(varietyId) &
              r.crossSectionId.equals(crossSectionId)))
        .getSingleOrNull();
    return _rateOf(row);
  }

  /// Returns every price-matrix cell currently stored, as [PriceCell]s.
  Future<List<PriceCell>> allCells() async {
    final rows = await _db.select(_db.priceRates).get();
    return rows.map(_cellOf).toList(growable: false);
  }

  /// Returns the cells whose rate is MISSING — the exact set of unpriced
  /// (variety, cross-section) pairs (Req 4.5).
  Future<List<PriceCell>> missingCells() async {
    final rows = await (_db.select(_db.priceRates)
          ..where((r) => r.rateNum.isNull() | r.rateDen.isNull()))
        .get();
    return rows.map(_cellOf).toList(growable: false);
  }

  /// Upserts a `PriceRates` row on the unique variety × cross-section key.
  ///
  /// Drift's `insertOnConflictUpdate` targets the table's primary key, not the
  /// unique business key, so we look the row up by the business key and either
  /// update it in place or insert a new one — keeping exactly one row per
  /// variety × cross-section.
  Future<void> _upsert({
    required int varietyId,
    required int crossSectionId,
    required BigInt? rateNum,
    required BigInt? rateDen,
  }) async {
    await _db.transaction(() async {
      final existing = await (_db.select(_db.priceRates)
            ..where((r) =>
                r.varietyId.equals(varietyId) &
                r.crossSectionId.equals(crossSectionId)))
          .getSingleOrNull();

      final num = rateNum == null ? null : _toInt(rateNum);
      final den = rateDen == null ? null : _toInt(rateDen);

      if (existing == null) {
        await _db.into(_db.priceRates).insert(
              PriceRatesCompanion.insert(
                varietyId: varietyId,
                crossSectionId: crossSectionId,
                rateNum: Value(num),
                rateDen: Value(den),
              ),
            );
      } else {
        await (_db.update(_db.priceRates)
              ..where((r) => r.id.equals(existing.id)))
            .write(
          PriceRatesCompanion(
            rateNum: Value(num),
            rateDen: Value(den),
          ),
        );
      }
    });
  }

  /// Reconstitutes the exact [Rational] rate from a row, or `null` if missing.
  static Rational? _rateOf(PriceRateRow? row) {
    if (row == null) return null;
    final num = row.rateNum;
    final den = row.rateDen;
    if (num == null || den == null) return null;
    return Rational(BigInt.from(num), BigInt.from(den));
  }

  static PriceCell _cellOf(PriceRateRow row) => PriceCell(
        varietyId: row.varietyId,
        crossSectionId: row.crossSectionId,
        rate: _rateOf(row),
      );

  /// Narrows a [BigInt] rate component to the `int` column storage, rejecting
  /// values that would overflow a 64-bit SQLite integer rather than silently
  /// truncating the rate.
  static int _toInt(BigInt value) {
    if (!value.isValidInt) {
      throw ArgumentError.value(
        value,
        'rate component',
        'rate numerator/denominator exceeds the 64-bit storage range',
      );
    }
    return value.toInt();
  }
}
