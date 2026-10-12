// Property-based test for negative-availability rejection (task 5.5).
//
// This exercises the design's Correctness Property 20 across many randomly
// generated sequences of stock adjustments/reversals (>= 100 iterations)
// rather than a handful of fixed examples:
//
//   * Property 20 - Negative-availability adjustments are rejected without
//     side effects (design.md -> Correctness Properties; Error Handling ->
//     negative-availability guard; Requirements 5.12, 21.19):
//     no sequence of adjustments/reversals can drive a Stock_Item's CONFIRMED
//     (sellable) availability negative. Any single movement that WOULD make
//     the confirmed balance negative is rejected (a blocking
//     `NegativeBalanceException`) and is a complete no-op: the balance is
//     unchanged, no `StockMovements` row is appended, and nothing is enqueued.
//     Movements that keep availability >= 0 apply normally. After every step
//     the maintained balance stays non-negative and still reconciles with the
//     signed sum of the ledger.
//
// The guard under test lives in `StockLedgerDao.recordMovement` (task 3.2) and
// is surfaced through `StockAdjustmentService.recordAdjustment` /
// `recordReversal` (task 5.4), which compose the ledger append and the
// pending-op enqueue into ONE transaction so a blocked movement rolls both
// back together.
//
// The test boots an in-memory `AppDatabase` (`openInMemoryDatabase`) so it runs
// under `flutter test` on Windows with no device and no hosted DB (the hosted
// path is never touched here). A fresh DB + seeded stock item is created per
// generated sequence so runs are independent.
//
// PBT framework: `package:glados`. `ExploreConfig(numRuns: ...)` fixes the
// iteration count (>= 100; 160 here) and seeds a deterministic `Random`, so a
// failure reproduces exactly. Only ONE property is implemented, as one test.

import 'package:glados/glados.dart';

import 'package:wood_cft/application/stock_adjustment_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/pending_operation_queue.dart';
import 'package:wood_cft/data/stock_ledger_dao.dart';
import 'package:wood_cft/data/tables.dart';

/// Deterministic exploration config giving the property >= 100 iterations
/// (160) from a fixed seed, so a failing sequence reproduces exactly.
final ExploreConfig _explore =
    ExploreConfig(numRuns: 160, random: Random(20240625));

/// A single generated step in the random sequence: a signed whole-piece
/// delta applied as an adjustment (adjust/reverse share the identical guard).
/// Range spans both large credits and large debits so sequences routinely
/// probe the zero boundary from both sides.
final Generator<int> _delta = any.intInRange(-60, 61); // -60..60 inclusive

/// A sequence of 1..24 signed deltas to apply in order against one stock item.
final Generator<List<int>> _deltas =
    any.listWithLengthInRange(1, 25, _delta);

/// The starting CONFIRMED balance of the seeded stock item (0..40), so some
/// sequences start empty (every debit is rejected) and some start with stock.
final Generator<int> _startingPieces = any.intInRange(0, 41); // 0..40 inclusive

/// Seeds a plank variety + cross-section + stock item and establishes
/// [confirmedPieces] of CONFIRMED availability through a real confirmed
/// `opening` movement (so the reconciliation invariant holds from the start,
/// never by poking the row). Returns the stock item id.
Future<int> _seedStockItem(
  AppDatabase db, {
  required int confirmedPieces,
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
          lengthFt: 6,
        ),
      );
  if (confirmedPieces > 0) {
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
  group('Negative-availability rejection (glados)', () {
    // Property 20: Negative-availability adjustments are rejected without
    // side effects.
    //
    // For each generated (startingPieces, deltas) we replay the deltas as a
    // sequence of adjustments against ONE stock item and assert, at EVERY
    // step, that:
    //   * a movement that would drive confirmed availability < 0 is rejected
    //     with a NegativeBalanceException and is a complete no-op (balance,
    //     movement-row count, and enqueued-op count all unchanged);
    //   * a movement that keeps availability >= 0 applies exactly once;
    //   * the maintained confirmed balance never goes negative; and
    //   * the maintained balance always reconciles with the signed sum of the
    //     ledger.
    // The confirmed balance can therefore only ever equal the running sum of
    // the deltas that were actually accepted, which is >= 0 by construction.
    Glados2<int, List<int>>(_startingPieces, _deltas, _explore).test(
      'Feature: wood-cft-app, Property 20: Negative-availability adjustments '
      'are rejected without side effects - no sequence of adjustments can '
      'drive confirmed availability negative; any movement that would is '
      'rejected and leaves the balance, ledger, and queue unchanged '
      '(Requirements 5.12, 21.19)',
      (int startingPieces, List<int> deltas) async {
        final db = openInMemoryDatabase();
        try {
          final ledger = StockLedgerDao(db);
          final queue = PendingOperationQueue(db);
          final service = StockAdjustmentService(db);

          final stockItemId =
              await _seedStockItem(db, confirmedPieces: startingPieces);

          // The model of what SHOULD be sellable: only accepted movements
          // change it, and it can never go below zero.
          var expectedConfirmed = startingPieces;

          for (var i = 0; i < deltas.length; i++) {
            final delta = deltas[i];
            final key = 'adj-$i';

            final balancesBefore = await ledger.readStoredBalances(stockItemId);
            final countBefore = await _movementCount(db, stockItemId);
            final wouldGoNegative = balancesBefore.confirmedPieces + delta < 0;

            if (delta == 0) {
              // Zero-delta adjustments are rejected up front (a no-op change is
              // not a valid adjustment) and must leave everything untouched.
              await expectLater(
                service.recordAdjustment(
                  stockItemId: stockItemId,
                  deltaPieces: delta,
                  reason: 'generated step $i',
                  idempotencyKey: key,
                ),
                throwsArgumentError,
              );
              final after = await ledger.readStoredBalances(stockItemId);
              expect(after.confirmedPieces, balancesBefore.confirmedPieces);
              expect(await _movementCount(db, stockItemId), countBefore);
              expect(await queue.findByIdempotencyKey(key), isNull);
            } else if (wouldGoNegative) {
              // The guard must block this movement with a blocking exception
              // and leave NO side effects: balance, ledger row count, and the
              // pending-op queue are all unchanged.
              await expectLater(
                service.recordAdjustment(
                  stockItemId: stockItemId,
                  deltaPieces: delta,
                  reason: 'generated step $i',
                  idempotencyKey: key,
                ),
                throwsA(isA<NegativeBalanceException>()),
              );
              final after = await ledger.readStoredBalances(stockItemId);
              expect(after.confirmedPieces, balancesBefore.confirmedPieces);
              expect(await _movementCount(db, stockItemId), countBefore);
              expect(await queue.findByIdempotencyKey(key), isNull);
            } else {
              // A non-negative-resulting movement applies exactly once: the
              // balance moves by delta, a movement row is appended, and the op
              // is enqueued.
              final result = await service.recordAdjustment(
                stockItemId: stockItemId,
                deltaPieces: delta,
                reason: 'generated step $i',
                idempotencyKey: key,
              );
              expect(result.outcome, StockAdjustmentOutcome.recorded);
              expectedConfirmed += delta;
              final after = await ledger.readStoredBalances(stockItemId);
              expect(
                after.confirmedPieces,
                balancesBefore.confirmedPieces + delta,
              );
              expect(await _movementCount(db, stockItemId), countBefore + 1);
              expect(await queue.findByIdempotencyKey(key), isNotNull);
            }

            // Invariants that must hold after EVERY step: availability never
            // negative, matches the running sum of accepted deltas, and the
            // maintained balance reconciles with the ledger.
            final now = await ledger.readStoredBalances(stockItemId);
            expect(now.confirmedPieces, isNonNegative);
            expect(now.confirmedPieces, expectedConfirmed);
            expect(await ledger.reconcile(stockItemId), isTrue);
          }
        } finally {
          await db.close();
        }
      },
    );
  });
}
