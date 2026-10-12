/// Unit tests for opening-stock, adjustment, and reversal/undo with the
/// negative-stock guard (task 5.4).
///
/// These boot an in-memory [AppDatabase] (so they run under `flutter test` on
/// Windows with no device) and exercise [StockAdjustmentService]:
///
///   * opening stock adds to the (pending) balance and records a real
///     movement with history (5.10, 5.13);
///   * an adjustment with a reason succeeds; without a reason it is rejected
///     (5.10);
///   * a reversal/undo that would make available stock negative is BLOCKED and
///     leaves the balance unchanged (Req 21.19 → Property 20; 5.12);
///   * a valid reversal reduces stock and retains history — the movement row
///     count only ever grows, nothing is deleted (5.11, 5.13);
///   * an idempotent retry does not double-apply (5.9).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wood_cft/application/stock_adjustment_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/pending_operation_queue.dart';
import 'package:wood_cft/data/stock_ledger_dao.dart';
import 'package:wood_cft/data/tables.dart';

/// Seeds a plank variety + cross-section + stock item at [lengthFt] with an
/// optional starting CONFIRMED balance, and returns the stock item id.
///
/// A non-zero starting balance is established through a real confirmed
/// `opening` movement (via [StockLedgerDao]) rather than by poking the row, so
/// the reconciliation invariant (balance == signed sum of the ledger) holds
/// from the start. The seeding movement is counted and excluded by callers
/// that assert on movement growth.
Future<int> _seedStockItem(
  AppDatabase db, {
  int lengthFt = 6,
  int confirmedPieces = 0,
}) async {
  final varietyId = await db.into(db.woodVarieties).insert(
        WoodVarietiesCompanion.insert(
          name: 'Mahogany',
          createdAt: DateTime.utc(2024, 1, 1),
        ),
      );
  final crossSectionId = await db.into(db.crossSections).insert(
        CrossSectionsCompanion.insert(
          widthIn: 3,
          thicknessIn: 1,
          category: CategoryKind.plank,
          bunchSize: 1,
        ),
      );
  final stockItemId = await db.into(db.stockItems).insert(
        StockItemsCompanion.insert(
          varietyId: varietyId,
          crossSectionId: crossSectionId,
          lengthFt: lengthFt,
        ),
      );
  if (confirmedPieces != 0) {
    await StockLedgerDao(db).recordMovement(
      stockItemId: stockItemId,
      type: MovementType.opening,
      deltaPieces: confirmedPieces,
      idempotencyKey: 'seed-opening-$stockItemId',
      syncState: SyncState.confirmed,
      occurredAt: DateTime.utc(2024, 1, 1),
    );
  }
  return stockItemId;
}

/// Counts the stock-movement rows for [stockItemId].
Future<int> _movementCount(AppDatabase db, int stockItemId) async {
  final rows = await (db.select(db.stockMovements)
        ..where((m) => m.stockItemId.equals(stockItemId)))
      .get();
  return rows.length;
}

void main() {
  group('StockAdjustmentService — opening / adjust / reverse (task 5.4)', () {
    late AppDatabase db;
    late StockAdjustmentService service;
    late StockLedgerDao ledger;
    late PendingOperationQueue queue;

    setUp(() {
      db = openInMemoryDatabase();
      service = StockAdjustmentService(db);
      ledger = StockLedgerDao(db);
      queue = PendingOperationQueue(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
        'opening stock adds to balance (pending) and records a movement with '
        'history (5.10, 5.13)', () async {
      final stockItemId = await _seedStockItem(db);

      final result = await service.recordOpeningStock(
        stockItemId: stockItemId,
        openingPieces: 40,
        idempotencyKey: 'open-1',
      );

      expect(result.outcome, StockAdjustmentOutcome.recorded);
      expect(result.movementType, MovementType.opening);

      // Opening stock lands in the PENDING balance (not yet sellable).
      final balances = await ledger.readStoredBalances(stockItemId);
      expect(balances.pendingPieces, 40);
      expect(balances.confirmedPieces, 0);

      // A real movement row exists (history retained) and the op was enqueued.
      expect(await _movementCount(db, stockItemId), 1);
      expect(await queue.findByIdempotencyKey('open-1'), isNotNull);
      expect(await ledger.reconcile(stockItemId), isTrue);
    });

    test('adjustment with a reason succeeds and adjusts confirmed balance '
        '(5.10)', () async {
      final stockItemId = await _seedStockItem(db, confirmedPieces: 100);

      final result = await service.recordAdjustment(
        stockItemId: stockItemId,
        deltaPieces: -5,
        reason: 'damaged in storage',
        idempotencyKey: 'adj-1',
      );

      expect(result.outcome, StockAdjustmentOutcome.recorded);
      final balances = await ledger.readStoredBalances(stockItemId);
      expect(balances.confirmedPieces, 95);
      expect(await queue.findByIdempotencyKey('adj-1'), isNotNull);
      expect(await ledger.reconcile(stockItemId), isTrue);
    });

    test('adjustment without a reason is rejected (5.10)', () async {
      final stockItemId = await _seedStockItem(db, confirmedPieces: 100);

      await expectLater(
        service.recordAdjustment(
          stockItemId: stockItemId,
          deltaPieces: -5,
          reason: '   ',
          idempotencyKey: 'adj-empty',
        ),
        throwsArgumentError,
      );

      // Nothing new was recorded: balance unchanged, only the seed movement
      // remains, and the adjustment was never enqueued.
      final balances = await ledger.readStoredBalances(stockItemId);
      expect(balances.confirmedPieces, 100);
      expect(await _movementCount(db, stockItemId), 1);
      expect(await queue.findByIdempotencyKey('adj-empty'), isNull);
    });

    test(
        'a reversal that would make available stock negative is BLOCKED and '
        'leaves the balance unchanged (Req 21.19)', () async {
      // Only 10 pieces are confirmed/available (e.g. the rest already sold);
      // undoing a prior +30 inbound entry would drive availability to -20.
      final stockItemId = await _seedStockItem(db, confirmedPieces: 10);
      final countBefore = await _movementCount(db, stockItemId);

      await expectLater(
        service.recordReversal(
          stockItemId: stockItemId,
          deltaPieces: -30,
          reason: 'undo mistaken receiving entry',
          idempotencyKey: 'rev-negative',
        ),
        throwsA(isA<NegativeBalanceException>()),
      );

      // No side effects: balance unchanged, no new movement row (only the seed
      // movement remains), nothing enqueued.
      final balances = await ledger.readStoredBalances(stockItemId);
      expect(balances.confirmedPieces, 10);
      expect(await _movementCount(db, stockItemId), countBefore);
      expect(await queue.findByIdempotencyKey('rev-negative'), isNull);
      expect(await ledger.reconcile(stockItemId), isTrue);
    });

    test(
        'a valid reversal reduces stock and retains history (nothing deleted) '
        '(5.11, 5.13)', () async {
      final stockItemId = await _seedStockItem(db, confirmedPieces: 50);
      final countAfterSeed = await _movementCount(db, stockItemId);

      // First record an adjustment so there is prior history to reverse.
      await service.recordAdjustment(
        stockItemId: stockItemId,
        deltaPieces: 10,
        reason: 'recount correction',
        idempotencyKey: 'adj-prior',
      );
      final countAfterAdjust = await _movementCount(db, stockItemId);
      expect(countAfterAdjust, countAfterSeed + 1);

      final result = await service.recordReversal(
        stockItemId: stockItemId,
        deltaPieces: -10,
        reason: 'reverse the recount correction',
        idempotencyKey: 'rev-valid',
      );

      expect(result.outcome, StockAdjustmentOutcome.recorded);
      final balances = await ledger.readStoredBalances(stockItemId);
      expect(balances.confirmedPieces, 50); // 50 + 10 - 10

      // History is retained: the movement row count GREW (the original adjust
      // row is still present), it was never hard-deleted.
      expect(await _movementCount(db, stockItemId), countAfterAdjust + 1);
      expect(await ledger.reconcile(stockItemId), isTrue);
    });

    test('idempotent retry does not double-apply (5.9)', () async {
      final stockItemId = await _seedStockItem(db, confirmedPieces: 100);

      final first = await service.recordAdjustment(
        stockItemId: stockItemId,
        deltaPieces: -20,
        reason: 'shrinkage',
        idempotencyKey: 'adj-retry',
      );
      final second = await service.recordAdjustment(
        stockItemId: stockItemId,
        deltaPieces: -20,
        reason: 'shrinkage',
        idempotencyKey: 'adj-retry',
      );

      expect(first.outcome, StockAdjustmentOutcome.recorded);
      expect(second.outcome, StockAdjustmentOutcome.duplicateIgnored);

      // Applied exactly once: balance dropped by 20, not 40, and only the seed
      // movement plus a single adjust movement exist.
      final balances = await ledger.readStoredBalances(stockItemId);
      expect(balances.confirmedPieces, 80);
      expect(await _movementCount(db, stockItemId), 2);
      expect(await ledger.reconcile(stockItemId), isTrue);
    });
  });
}
