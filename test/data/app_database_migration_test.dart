/// Schema v1 -> v2 migration test (app-ux-revamp task 1.1).
///
/// Builds a database at the **v1** `draft_orders` shape (no `title`,
/// `updated_at`, or `invoice_id` columns) in a temp file, seeds a draft row and
/// stamps `user_version = 1`, then reopens [AppDatabase] over the same file so
/// the migration strategy runs `onUpgrade(1 -> 2)`. The test asserts the
/// additive migration preserved the seeded row and added the three new columns
/// (design Property 37, Requirement 8.2).
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/tables.dart';

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wood_cft_migration');
    dbFile = File('${tempDir.path}/cache.sqlite');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('v1 -> v2 upgrade preserves existing draft rows and adds columns',
      () async {
    // --- Create a v1 draft_orders shape and seed a row directly, then stamp
    // user_version = 1 so the next open is seen as a v1 database to upgrade.
    final setup = AppDatabase.forTesting(NativeDatabase(dbFile));
    await setup.customStatement('DROP TABLE IF EXISTS draft_orders');
    await setup.customStatement(
      'CREATE TABLE draft_orders ('
      'id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      'status INTEGER NOT NULL, '
      'customer_name TEXT NULL, '
      'customer_phone TEXT NULL, '
      'created_at INTEGER NOT NULL)',
    );
    await setup.customStatement(
      'INSERT INTO draft_orders '
      '(id, status, customer_name, customer_phone, created_at) '
      'VALUES (1, 0, ?, ?, ?)',
      <Object?>['Asha', '555-0100', 1700000000],
    );
    await setup.customStatement('PRAGMA user_version = 1');
    await setup.close();

    // --- Reopen; the migration strategy detects v1 -> v2 and runs onUpgrade.
    final migrated = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(migrated.close);

    // The old row survived with its original data intact.
    final rows = await migrated.select(migrated.draftOrders).get();
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.id, 1);
    expect(row.status, DraftStatus.draft);
    expect(row.customerName, 'Asha');
    expect(row.customerPhone, '555-0100');

    // The three new columns exist and are readable; title/invoiceId default to
    // null, updatedAt is backfilled with a non-null timestamp.
    expect(row.title, isNull);
    expect(row.invoiceId, isNull);
    expect(row.updatedAt, isNotNull);

    // The new columns are writable at the v2 shape.
    await migrated.update(migrated.draftOrders).replace(
          row.copyWith(
            title: const Value('Walk-in order'),
            status: DraftStatus.sold,
          ),
        );
    final updated = await (migrated.select(migrated.draftOrders)
          ..where((t) => t.id.equals(1)))
        .getSingle();
    expect(updated.title, 'Walk-in order');
    expect(updated.status, DraftStatus.sold);
  });
}
