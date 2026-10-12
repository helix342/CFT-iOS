/// Repository tests for the business-profile singleton (task 13.1).
///
/// Boots an in-memory [AppDatabase] (runs under `flutter test` on Windows) and
/// asserts:
///   * a fresh install loads [BusinessProfile.empty] — no assumed name
///     (Requirement 18.2) and no fabricated GSTIN (Requirement 18.5);
///   * a written profile round-trips exactly through the singleton row;
///   * repeated saves update the single row in place (upsert on id = 1).
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/business_settings_repository.dart';
import 'package:wood_cft/domain/business_settings.dart';

void main() {
  late AppDatabase db;
  late BusinessSettingsRepository repo;

  setUp(() {
    db = openInMemoryDatabase();
    repo = BusinessSettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('default profile is empty on a fresh install — Req 18.2, 18.5',
      () async {
    final loaded = await repo.load();

    expect(loaded, BusinessProfile.empty);
    expect(loaded.name, isEmpty);
    expect(loaded.name, isNot(contains('Zenith')));
    expect(loaded.gstin, isNull);
    expect(loaded.logo, isNull);
    expect(loaded.invoicePrefix, isEmpty);
  });

  test('save then load round-trips the singleton exactly', () async {
    final profile = BusinessProfile(
      name: 'Timber Mart',
      address: '12 Mill Road',
      phone: '9876543210',
      gstin: '29ABCDE1234F1Z5',
      invoicePrefix: 'TM-',
      logo: Uint8List.fromList([10, 20, 30, 40]),
    );

    await repo.save(profile);
    final loaded = await repo.load();

    expect(loaded.name, 'Timber Mart');
    expect(loaded.address, '12 Mill Road');
    expect(loaded.phone, '9876543210');
    expect(loaded.gstin, '29ABCDE1234F1Z5');
    expect(loaded.invoicePrefix, 'TM-');
    expect(loaded.logo, equals(Uint8List.fromList([10, 20, 30, 40])));
    expect(loaded, equals(profile));
  });

  test('absent GSTIN round-trips as null (not fabricated) — Req 18.5',
      () async {
    const profile = BusinessProfile(name: 'No Reg Shop', invoicePrefix: 'NR-');

    await repo.save(profile);
    final loaded = await repo.load();

    expect(loaded.gstin, isNull);
    expect(loaded.name, 'No Reg Shop');
  });

  test('repeated saves update the single row in place (upsert on id = 1)',
      () async {
    await repo.save(const BusinessProfile(name: 'First', invoicePrefix: 'A-'));
    await repo.save(const BusinessProfile(name: 'Second', invoicePrefix: 'B-'));

    final loaded = await repo.load();
    expect(loaded.name, 'Second');
    expect(loaded.invoicePrefix, 'B-');

    // Exactly one row exists in the singleton table.
    final rows = await db.select(db.businessSettings).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, kBusinessSettingsSingletonId);
  });
}
