/// Schema / migration tests for the Wood CFT local SQLite cache (task 3.1).
///
/// These tests boot an **in-memory** [AppDatabase] (so they run under
/// `flutter test` on Windows with no device), let the migration strategy apply
/// the full schema, and then assert the design.md -> Data Models invariants are
/// actually enforced by the schema at runtime:
///
///   * a duplicate stock key `(variety, cross_section, length)` is rejected;
///   * a duplicate `idempotency_key` is rejected;
///   * an orphan invoice line (FK to a non-existent invoice) is rejected,
///     and a null `invoice_id` is impossible by the schema (compile-time).
///
/// They do NOT exercise the ledger balance logic (task 3.2) or the queue drain
/// (task 3.3) — only the schema and its constraints.
library;

import 'package:drift/native.dart' show SqliteException;
import 'package:flutter_test/flutter_test.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/tables.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = openInMemoryDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  /// Inserts a variety + cross-section and returns a ready-to-insert
  /// [StockItemsCompanion.insert] for the shared `(variety, 2x1 reaper, 6 ft)`
  /// stock key used by several tests.
  Future<StockItemsCompanion> seedStockKey() async {
    final varietyId = await db
        .into(db.woodVarieties)
        .insert(
          WoodVarietiesCompanion.insert(
            name: 'Mahogany',
            createdAt: DateTime.now().toUtc(),
          ),
        );
    final crossSectionId = await db
        .into(db.crossSections)
        .insert(
          CrossSectionsCompanion.insert(
            widthIn: 2,
            thicknessIn: 1,
            category: CategoryKind.reaper,
            bunchSize: 10,
          ),
        );
    return StockItemsCompanion.insert(
      varietyId: varietyId,
      crossSectionId: crossSectionId,
      lengthFt: 6,
    );
  }

  test('migration boots an empty in-memory database with the full schema', () async {
    // Selecting from a table forces the connection open, which applies the
    // migration (onCreate -> createAll) and the beforeOpen PRAGMA. A successful
    // query against a freshly-created table proves the schema was built.
    final varieties = await db.select(db.woodVarieties).get();
    expect(varieties, isEmpty);

    // Every declared table is registered on the generated database and the
    // schema version matches the single initial version.
    expect(db.schemaVersion, kSchemaVersion);
    expect(db.allTables.length, 18);

    // Foreign keys must be ON (beforeOpen) so FK invariants are enforced.
    final fkPragma =
        await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fkPragma.data.values.first, 1);
  });

  test('duplicate stock key (variety, cross_section, length) is rejected', () async {
    final stockItem = await seedStockKey();

    // First insert succeeds.
    await db.into(db.stockItems).insert(stockItem);

    // A second row with the same (variety, cross_section, length) violates the
    // unique key and must be rejected.
    await expectLater(
      db.into(db.stockItems).insert(stockItem),
      throwsA(isA<SqliteException>()),
    );

    final rows = await db.select(db.stockItems).get();
    expect(rows, hasLength(1));
  });

  test('a different length with the same variety/cross-section is allowed', () async {
    final sixFt = await seedStockKey();
    await db.into(db.stockItems).insert(sixFt);

    // Only the length differs, so this is a distinct stock key and is allowed.
    await db.into(db.stockItems).insert(
          StockItemsCompanion.insert(
            varietyId: sixFt.varietyId.value,
            crossSectionId: sixFt.crossSectionId.value,
            lengthFt: 7,
          ),
        );

    final rows = await db.select(db.stockItems).get();
    expect(rows, hasLength(2));
  });

  test('duplicate idempotency_key is rejected on the movement ledger', () async {
    final stockItemId = await db
        .into(db.stockItems)
        .insert(await seedStockKey());

    StockMovementsCompanion movement(String key) =>
        StockMovementsCompanion.insert(
          stockItemId: stockItemId,
          type: MovementType.receive,
          deltaPieces: 10,
          occurredAt: DateTime.now().toUtc(),
          idempotencyKey: key,
          syncState: SyncState.pending,
        );

    await db.into(db.stockMovements).insert(movement('op-123'));

    // Re-using the same idempotency key must be rejected so retries/duplicates
    // cannot double-apply (design.md -> Transaction Boundaries & Sync).
    await expectLater(
      db.into(db.stockMovements).insert(movement('op-123')),
      throwsA(isA<SqliteException>()),
    );

    final rows = await db.select(db.stockMovements).get();
    expect(rows, hasLength(1));
  });

  test('duplicate idempotency_key is rejected on the pending-op queue', () async {
    PendingOperationsCompanion op(String key) =>
        PendingOperationsCompanion.insert(
          opType: OpType.receiveEntry,
          payload: '{}',
          idempotencyKey: key,
          enqueuedAt: DateTime.now().toUtc(),
          syncState: SyncState.pending,
        );

    await db.into(db.pendingOperations).insert(op('enqueue-1'));

    await expectLater(
      db.into(db.pendingOperations).insert(op('enqueue-1')),
      throwsA(isA<SqliteException>()),
    );

    final rows = await db.select(db.pendingOperations).get();
    expect(rows, hasLength(1));
  });

  test('an orphan invoice line (FK to a non-existent invoice) is rejected', () async {
    // No invoice with id 999 exists. The NOT NULL foreign key must reject this
    // insert, so an invoice line can never be an orphan.
    await expectLater(
      db.into(db.invoiceLines).insert(
            InvoiceLinesCompanion.insert(
              invoiceId: 999,
              varietyName: 'Mahogany',
              crossSectionLabel: '2 × 1 in',
              lengthFt: 6,
              pieces: 10,
              exactCftNum: 5,
              exactCftDen: 6,
              rateNum: 120000,
              rateDen: 1,
              lineAmountPaise: 100000,
            ),
          ),
      throwsA(isA<SqliteException>()),
    );

    final rows = await db.select(db.invoiceLines).get();
    expect(rows, isEmpty);
  });

  test('an invoice line referencing a real invoice is accepted', () async {
    final invoiceId = await db.into(db.invoices).insert(
          InvoicesCompanion.insert(
            invoiceNumber: 'INV-0001',
            status: InvoiceStatus.finalized,
            goodsSubtotalPaise: 166667,
            taxPaise: 0,
            loadingPaise: 10000,
            payablePaise: 176667,
            totalCftNum: 25,
            totalCftDen: 18,
            taxPolicySnapshot: '{}',
            loadingPolicySnapshot: '{}',
            businessProfileSnapshot: '{}',
            finalizedAt: DateTime.now().toUtc(),
            idempotencyKey: 'finalize-1',
          ),
        );

    await db.into(db.invoiceLines).insert(
          InvoiceLinesCompanion.insert(
            invoiceId: invoiceId,
            varietyName: 'Mahogany',
            crossSectionLabel: '2 × 1 in',
            lengthFt: 6,
            pieces: 50,
            exactCftNum: 25,
            exactCftDen: 18,
            rateNum: 120000,
            rateDen: 1,
            lineAmountPaise: 166667,
          ),
        );

    final rows = await db.select(db.invoiceLines).get();
    expect(rows, hasLength(1));
    expect(rows.single.invoiceId, invoiceId);
  });

  test('duplicate invoice_number is rejected', () async {
    InvoicesCompanion invoice(String number) => InvoicesCompanion.insert(
          invoiceNumber: number,
          status: InvoiceStatus.finalized,
          goodsSubtotalPaise: 0,
          taxPaise: 0,
          loadingPaise: 0,
          payablePaise: 0,
          totalCftNum: 0,
          totalCftDen: 1,
          taxPolicySnapshot: '{}',
          loadingPolicySnapshot: '{}',
          businessProfileSnapshot: '{}',
          finalizedAt: DateTime.now().toUtc(),
          idempotencyKey: 'key-$number',
        );

    await db.into(db.invoices).insert(invoice('INV-0001'));

    await expectLater(
      db.into(db.invoices).insert(invoice('INV-0001')),
      throwsA(isA<SqliteException>()),
    );
  });
}
