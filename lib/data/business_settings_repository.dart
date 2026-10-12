/// Persistence for the business-profile singleton (task 13.1).
///
/// [BusinessSettingsRepository] reads and writes the single `BusinessSettings`
/// row (always `id = 1`) in the drift local cache (design.md -> Data Models,
/// BusinessSettings singleton) and maps it to/from the pure-Dart
/// [BusinessProfile] domain value object.
///
/// Honesty rules (Requirement 18): when no row exists yet the repository
/// returns [BusinessProfile.empty] — a blank name (never "Zenith Systems",
/// Requirement 18.2) and an absent GSTIN (never fabricated, Requirement 18.5).
library;

import 'package:drift/drift.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/domain/business_settings.dart';

/// The fixed primary key of the business-profile singleton row.
const int kBusinessSettingsSingletonId = 1;

/// Reads and writes the business-profile singleton in the local cache.
class BusinessSettingsRepository {
  /// Creates a repository backed by [_db].
  BusinessSettingsRepository(this._db);

  final AppDatabase _db;

  /// Loads the current business profile.
  ///
  /// Returns [BusinessProfile.empty] when the singleton row has not been
  /// written yet, so a fresh install exposes no assumed name (Requirement
  /// 18.2) and no fabricated registration (Requirement 18.5).
  Future<BusinessProfile> load() async {
    final row =
        await (_db.select(_db.businessSettings)
              ..where((t) => t.id.equals(kBusinessSettingsSingletonId)))
            .getSingleOrNull();
    if (row == null) return BusinessProfile.empty;
    return _fromRow(row);
  }

  /// A stream of the business profile that emits on every change.
  Stream<BusinessProfile> watch() {
    return (_db.select(_db.businessSettings)
          ..where((t) => t.id.equals(kBusinessSettingsSingletonId)))
        .watchSingleOrNull()
        .map((row) => row == null ? BusinessProfile.empty : _fromRow(row));
  }

  /// Writes [profile] to the singleton row, inserting it if absent and
  /// updating it in place otherwise (upsert on the fixed id).
  Future<void> save(BusinessProfile profile) async {
    await _db
        .into(_db.businessSettings)
        .insertOnConflictUpdate(_toCompanion(profile));
  }

  BusinessProfile _fromRow(BusinessSettingsRow row) {
    return BusinessProfile(
      name: row.name,
      address: row.address,
      phone: row.phone,
      logo: row.logo,
      gstin: row.gstin,
      invoicePrefix: row.invoicePrefix,
    );
  }

  BusinessSettingsCompanion _toCompanion(BusinessProfile profile) {
    return BusinessSettingsCompanion(
      id: const Value(kBusinessSettingsSingletonId),
      name: Value(profile.name),
      address: Value(profile.address),
      phone: Value(profile.phone),
      logo: Value(profile.logo),
      gstin: Value(profile.gstin),
      invoicePrefix: Value(profile.invoicePrefix),
    );
  }
}
