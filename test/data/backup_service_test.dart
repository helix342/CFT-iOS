/// Unit + property tests for [BackupService] export + versioned restore
/// (task 14.1).
///
/// These boot an in-memory [AppDatabase] (so they run under `flutter test` on
/// Windows with no device) and exercise the backup round-trip against the
/// design's "(f) Backup restore" contract and Requirement 16:
///
///   * export -> restore into a FRESH in-memory DB reproduces every stock
///     balance and the invoice identity exactly, with no duplicate stock
///     movement (16.1, 21.25);
///   * a backup whose `schema_version` is wrong, or whose checksum/structure
///     is corrupt, is REJECTED before any write — the DB is left unchanged
///     (16.4);
///   * restoring the same backup twice does not duplicate any stock movement
///     (16.5);
///   * Property 29: backup/restore round-trip preserves balances + invoice
///     identity with no duplicate movement, and invalid schema is rejected
///     without writing (>=100 iterations).
///
/// PBT framework: `package:glados` (re-exports `package:test`), matching the
/// existing data/application property tests.
library;

import 'package:glados/glados.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/backup_service.dart';
import 'package:wood_cft/data/stock_ledger_dao.dart';
import 'package:wood_cft/data/tables.dart';

/// A small seeded dataset: catalog + a stock item with movements + one invoice.
class _Seeded {
  const _Seeded({
    required this.stockItemId,
    required this.invoiceNumber,
    required this.movementCount,
  });

  final int stockItemId;
  final String invoiceNumber;
  final int movementCount;
}

/// Seeds catalog, a stock item, a mix of stock movements, and one invoice with
/// a line. Returns identifying facts to assert against after a round-trip.
Future<_Seeded> _seed(
  AppDatabase db, {
  int openingPieces = 50,
  int salePieces = 20,
}) async {
  final ledger = StockLedgerDao(db);

  final varietyId = await db.into(db.woodVarieties).insert(
        WoodVarietiesCompanion.insert(
          name: 'Mahogany',
          createdAt: DateTime.utc(2024, 1, 1),
        ),
      );
  final crossSectionId = await db.into(db.crossSections).insert(
        CrossSectionsCompanion.insert(
          widthIn: 2,
          thicknessIn: 1,
          category: CategoryKind.reaper,
          bunchSize: 10,
        ),
      );
  final stockItemId = await db.into(db.stockItems).insert(
        StockItemsCompanion.insert(
          varietyId: varietyId,
          crossSectionId: crossSectionId,
          lengthFt: 6,
        ),
      );

  // Opening stock (confirmed) + a pending receive to exercise both balances.
  await ledger.recordMovement(
    stockItemId: stockItemId,
    type: MovementType.opening,
    deltaPieces: openingPieces,
    idempotencyKey: 'open-$stockItemId',
    syncState: SyncState.confirmed,
    occurredAt: DateTime.utc(2024, 1, 2),
  );
  await ledger.recordMovement(
    stockItemId: stockItemId,
    type: MovementType.receive,
    deltaPieces: 10,
    idempotencyKey: 'recv-$stockItemId',
    syncState: SyncState.pending,
    occurredAt: DateTime.utc(2024, 1, 3),
  );

  // A finalized invoice with one line, plus the Sale movement that deducts it.
  const invoiceNumber = 'INV-0001';
  final invoiceId = await db.into(db.invoices).insert(
        InvoicesCompanion.insert(
          invoiceNumber: invoiceNumber,
          status: InvoiceStatus.finalized,
          goodsSubtotalPaise: 166667,
          taxPaise: 0,
          loadingPaise: 10000,
          payablePaise: 176667,
          totalCftNum: 5,
          totalCftDen: 1,
          taxPolicySnapshot: '{"mode":"noGst"}',
          loadingPolicySnapshot: '{"low":10000}',
          businessProfileSnapshot: '{"name":"Shop"}',
          finalizedAt: DateTime.utc(2024, 1, 4),
          idempotencyKey: 'inv-$invoiceNumber',
        ),
      );
  await db.into(db.invoiceLines).insert(
        InvoiceLinesCompanion.insert(
          invoiceId: invoiceId,
          varietyName: 'Mahogany',
          crossSectionLabel: '2 × 1 in',
          lengthFt: 6,
          pieces: salePieces,
          exactCftNum: 5,
          exactCftDen: 2,
          rateNum: 66667,
          rateDen: 1,
          lineAmountPaise: 166667,
        ),
      );
  await ledger.recordMovement(
    stockItemId: stockItemId,
    type: MovementType.sale,
    deltaPieces: -salePieces,
    idempotencyKey: 'sale-$invoiceNumber',
    syncState: SyncState.confirmed,
    invoiceId: invoiceId,
    occurredAt: DateTime.utc(2024, 1, 4),
  );

  final movements = await db.select(db.stockMovements).get();
  return _Seeded(
    stockItemId: stockItemId,
    invoiceNumber: invoiceNumber,
    movementCount: movements.length,
  );
}

/// Counts rows in [table].
Future<int> _count(AppDatabase db, String table) async {
  final rows = await db.customSelect('SELECT COUNT(*) AS c FROM "$table"').get();
  return rows.single.data['c'] as int;
}

void main() {
  group('BackupService — export + versioned restore (task 14.1)', () {
    late AppDatabase db;

    setUp(() {
      db = openInMemoryDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    test('export carries BackupMeta: schema_version, app_version, '
        'exported_at (UTC), checksum (16.1)', () async {
      await _seed(db);
      final service = BackupService(db, appVersion: '1.2.3');
      final doc = await service.exportToMap(
        exportedAt: DateTime.utc(2024, 6, 1, 12),
      );

      final meta = BackupService.readMeta(doc);
      expect(meta.schemaVersion, kSchemaVersion);
      expect(meta.appVersion, '1.2.3');
      expect(meta.exportedAt.isUtc, isTrue);
      expect(meta.exportedAt, DateTime.utc(2024, 6, 1, 12));
      expect(meta.checksum, isNotEmpty);
    });

    test('round-trip into a FRESH db reproduces balances and invoice identity '
        'exactly, with no duplicate movement (16.1, 21.25)', () async {
      final seeded = await _seed(db);
      final sourceBalances =
          await StockLedgerDao(db).readStoredBalances(seeded.stockItemId);
      final doc = await BackupService(db).exportToMap();

      // Restore into a brand-new, empty database.
      final fresh = openInMemoryDatabase();
      addTearDown(fresh.close);
      await BackupService(fresh).restoreFromMap(doc);

      // Balances reproduced exactly.
      final restoredBalances =
          await StockLedgerDao(fresh).readStoredBalances(seeded.stockItemId);
      expect(restoredBalances, sourceBalances);
      // And the maintained balance still reconciles with the restored ledger.
      expect(await StockLedgerDao(fresh).reconcile(seeded.stockItemId), isTrue);

      // Invoice identity reproduced exactly (same number, same primary key).
      final invoices = await fresh.select(fresh.invoices).get();
      expect(invoices, hasLength(1));
      expect(invoices.single.invoiceNumber, seeded.invoiceNumber);
      final lines = await fresh.select(fresh.invoiceLines).get();
      expect(lines, hasLength(1));
      expect(lines.single.invoiceId, invoices.single.id);

      // No stock movement duplicated.
      expect(
        await _count(fresh, 'stock_movements'),
        seeded.movementCount,
      );
    });

    test('a backup with a wrong schema_version is REJECTED with no writes '
        '(16.4)', () async {
      await _seed(db);
      final doc = await BackupService(db).exportToMap();
      // Tamper the schema version to an unsupported value.
      (doc['meta'] as Map<String, dynamic>)['schema_version'] =
          kSchemaVersion + 99;

      final fresh = openInMemoryDatabase();
      addTearDown(fresh.close);
      // Put a sentinel row in the fresh db so we can prove nothing was touched.
      await fresh.into(fresh.woodVarieties).insert(
            WoodVarietiesCompanion.insert(
              name: 'SENTINEL',
              createdAt: DateTime.utc(2024, 1, 1),
            ),
          );

      await expectLater(
        BackupService(fresh).restoreFromMap(doc),
        throwsA(isA<BackupValidationException>()),
      );

      // No partial writes: the sentinel row is still the only variety, and no
      // stock movements / invoices were imported.
      final varieties = await fresh.select(fresh.woodVarieties).get();
      expect(varieties, hasLength(1));
      expect(varieties.single.name, 'SENTINEL');
      expect(await _count(fresh, 'stock_movements'), 0);
      expect(await _count(fresh, 'invoices'), 0);
    });

    test('a corrupt backup (checksum mismatch) is REJECTED with no writes '
        '(16.4)', () async {
      await _seed(db);
      final doc = await BackupService(db).exportToMap();
      // Corrupt a data row without updating the checksum.
      final movements = (doc['data']
          as Map<String, dynamic>)['stock_movements'] as List<dynamic>;
      (movements.first as Map<String, dynamic>)['delta_pieces'] = 999999;

      final fresh = openInMemoryDatabase();
      addTearDown(fresh.close);

      await expectLater(
        BackupService(fresh).restoreFromMap(doc),
        throwsA(isA<BackupValidationException>()),
      );
      expect(await _count(fresh, 'stock_movements'), 0);
    });

    test('restoring the same backup twice does not duplicate movements '
        '(16.5)', () async {
      final seeded = await _seed(db);
      final doc = await BackupService(db).exportToMap();

      final fresh = openInMemoryDatabase();
      addTearDown(fresh.close);
      await BackupService(fresh).restoreFromMap(doc);
      final afterFirst = await _count(fresh, 'stock_movements');

      // Restore the identical backup a second time over the restored data.
      await BackupService(fresh).restoreFromMap(doc);
      final afterSecond = await _count(fresh, 'stock_movements');

      expect(afterFirst, seeded.movementCount);
      expect(afterSecond, seeded.movementCount);
      // Balances remain correct and reconcile after the double restore.
      expect(await StockLedgerDao(fresh).reconcile(seeded.stockItemId), isTrue);
    });

    test('JSON string round-trip restores identically', () async {
      final seeded = await _seed(db);
      final json = await BackupService(db).exportToJson();

      final fresh = openInMemoryDatabase();
      addTearDown(fresh.close);
      await BackupService(fresh).restoreFromJson(json);

      final invoices = await fresh.select(fresh.invoices).get();
      expect(invoices.single.invoiceNumber, seeded.invoiceNumber);
      expect(await _count(fresh, 'stock_movements'), seeded.movementCount);
    });

    test('invalid JSON is rejected as a validation failure', () async {
      final fresh = openInMemoryDatabase();
      addTearDown(fresh.close);
      await expectLater(
        BackupService(fresh).restoreFromJson('not json at all'),
        throwsA(isA<BackupValidationException>()),
      );
    });
  });

  // --- Property 29 ----------------------------------------------------------
  //
  // Feature: wood-cft-app, Property 29: for any dataset, restoring a backup
  // produced from it preserves every balance and invoice identity exactly,
  // adds no duplicate movement, and an invalid schema is rejected without
  // writing anything.
  group('Backup/restore round-trip (Property 29, glados)', () {
    Glados<List<int>>(
      // Each element is an opening-stock piece count (0..199) for one SKU; the
      // list length (0..6) is the number of SKUs in the random dataset.
      any.listWithLengthInRange(0, 6, any.intInRange(0, 200)),
      ExploreConfig(numRuns: 150, random: Random(20240614)),
    ).test(
      'Feature: wood-cft-app, Property 29: backup/restore round-trip preserves '
      'balances + invoice identity with no duplicate movement, and an invalid '
      'schema is rejected without writing (Requirements 16.1, 16.4, 16.5, '
      '21.25)',
      (openings) async {
        final source = openInMemoryDatabase();
        try {
          final ledger = StockLedgerDao(source);
          final varietyId = await source.into(source.woodVarieties).insert(
                WoodVarietiesCompanion.insert(
                  name: 'V',
                  createdAt: DateTime.utc(2024, 1, 1),
                ),
              );
          final csId = await source.into(source.crossSections).insert(
                CrossSectionsCompanion.insert(
                  widthIn: 3,
                  thicknessIn: 1,
                  category: CategoryKind.plank,
                  bunchSize: 1,
                ),
              );

          final stockItemIds = <int>[];
          for (var i = 0; i < openings.length; i++) {
            final id = await source.into(source.stockItems).insert(
                  StockItemsCompanion.insert(
                    varietyId: varietyId,
                    crossSectionId: csId,
                    lengthFt: 2 + i, // 2..7, distinct per SKU
                  ),
                );
            stockItemIds.add(id);
            if (openings[i] > 0) {
              await ledger.recordMovement(
                stockItemId: id,
                type: MovementType.opening,
                deltaPieces: openings[i],
                idempotencyKey: 'open-$id',
                syncState: SyncState.confirmed,
                occurredAt: DateTime.utc(2024, 1, 2),
              );
            }
          }

          // One invoice when there is at least one SKU, to exercise identity.
          String? invoiceNumber;
          if (stockItemIds.isNotEmpty) {
            invoiceNumber = 'INV-${openings.length}';
            await source.into(source.invoices).insert(
                  InvoicesCompanion.insert(
                    invoiceNumber: invoiceNumber,
                    status: InvoiceStatus.finalized,
                    goodsSubtotalPaise: 1000,
                    taxPaise: 0,
                    loadingPaise: 10000,
                    payablePaise: 11000,
                    totalCftNum: 1,
                    totalCftDen: 1,
                    taxPolicySnapshot: '{}',
                    loadingPolicySnapshot: '{}',
                    businessProfileSnapshot: '{}',
                    finalizedAt: DateTime.utc(2024, 1, 4),
                    idempotencyKey: 'inv-$invoiceNumber',
                  ),
                );
          }

          final sourceBalances = <int, LedgerBalances>{};
          for (final id in stockItemIds) {
            sourceBalances[id] = await ledger.readStoredBalances(id);
          }
          final sourceMovements = await _count(source, 'stock_movements');

          final doc = await BackupService(source).exportToMap();

          // 1) Round-trip into a fresh DB preserves everything exactly.
          final fresh = openInMemoryDatabase();
          try {
            await BackupService(fresh).restoreFromMap(doc);
            final freshLedger = StockLedgerDao(fresh);
            for (final id in stockItemIds) {
              expect(await freshLedger.readStoredBalances(id),
                  sourceBalances[id]);
              expect(await freshLedger.reconcile(id), isTrue);
            }
            expect(await _count(fresh, 'stock_movements'), sourceMovements);
            final invoices = await fresh.select(fresh.invoices).get();
            if (invoiceNumber == null) {
              expect(invoices, isEmpty);
            } else {
              expect(invoices.single.invoiceNumber, invoiceNumber);
            }

            // 2) Restoring the same backup twice never duplicates a movement.
            await BackupService(fresh).restoreFromMap(doc);
            expect(await _count(fresh, 'stock_movements'), sourceMovements);
          } finally {
            await fresh.close();
          }

          // 3) An invalid schema_version is rejected with no writes.
          final tampered = await BackupService(source).exportToMap();
          (tampered['meta'] as Map<String, dynamic>)['schema_version'] =
              kSchemaVersion + 1;
          final target = openInMemoryDatabase();
          try {
            await expectLater(
              BackupService(target).restoreFromMap(tampered),
              throwsA(isA<BackupValidationException>()),
            );
            expect(await _count(target, 'stock_movements'), 0);
            expect(await _count(target, 'wood_varieties'), 0);
          } finally {
            await target.close();
          }
        } finally {
          await source.close();
        }
      },
    );
  });
}
