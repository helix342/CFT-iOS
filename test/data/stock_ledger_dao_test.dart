/// Unit + property tests for the movement ledger with a transactionally
/// maintained balance and the reconciliation invariant (task 3.2).
///
/// These boot an in-memory [AppDatabase] (so they run under `flutter test` on
/// Windows with no device) and exercise [StockLedgerDao]:
///
///   * a pending receive adds to the pending balance; confirming it moves the
///     delta pending -> confirmed (design.md -> "Local cache vs hosted
///     schema"; Sync engine);
///   * the reconciliation invariant holds after a random mix of movements
///     (Property 22 target; Requirements 5.13, 6.2);
///   * a movement that would drive the CONFIRMED balance negative is rejected
///     with no side effects (Req 21.19 intent; Requirement 5.12);
///   * a duplicate idempotency key applies the stock effect exactly once
///     (Requirements 5.9, 19.9).
///
/// PBT framework: `package:glados` (re-exports `package:test`), matching the
/// existing domain property tests.
library;

import 'package:glados/glados.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/stock_ledger_dao.dart';
import 'package:wood_cft/data/tables.dart';

/// Seeds a variety + cross-section + stock item and returns the stock item id.
Future<int> _seedStockItem(AppDatabase db, {int lengthFt = 6}) async {
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
  return db.into(db.stockItems).insert(
        StockItemsCompanion.insert(
          varietyId: varietyId,
          crossSectionId: crossSectionId,
          lengthFt: lengthFt,
        ),
      );
}

/// One randomly generated movement step used by the Property 22 test.
/// [isReceive] chooses a receive (pending or confirmed) over a confirmed
/// adjustment; [pending] only applies to receives; [magnitude] is 1..39.
class _Step {
  const _Step(this.isReceive, this.pending, this.magnitude);

  final bool isReceive;
  final bool pending;
  final int magnitude;

  @override
  String toString() =>
      '_Step(isReceive: $isReceive, pending: $pending, mag: $magnitude)';
}

void main() {
  group('StockLedgerDao — transactional balance and reconciliation', () {
    late AppDatabase db;
    late StockLedgerDao dao;
    late int stockItemId;

    setUp(() async {
      db = openInMemoryDatabase();
      dao = StockLedgerDao(db);
      stockItemId = await _seedStockItem(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('a pending receive adds to pending, confirm moves pending -> confirmed',
        () async {
      final outcome = await dao.recordMovement(
        stockItemId: stockItemId,
        type: MovementType.receive,
        deltaPieces: 30,
        idempotencyKey: 'recv-1',
        syncState: SyncState.pending,
      );
      expect(outcome, MovementOutcome.applied);

      // Pending receive is display-only: pending += 30, confirmed stays 0.
      expect(
        await dao.readStoredBalances(stockItemId),
        const LedgerBalances(confirmedPieces: 0, pendingPieces: 30),
      );
      // Not sellable yet, but the ledger reconciles.
      expect(await dao.reconcile(stockItemId), isTrue);

      await dao.confirmMovement('recv-1');

      // Confirming shifts the delta from pending to confirmed (sellable).
      expect(
        await dao.readStoredBalances(stockItemId),
        const LedgerBalances(confirmedPieces: 30, pendingPieces: 0),
      );
      expect(await dao.reconcile(stockItemId), isTrue);

      // Confirming again is a no-op (idempotent).
      await dao.confirmMovement('recv-1');
      expect(
        await dao.readStoredBalances(stockItemId),
        const LedgerBalances(confirmedPieces: 30, pendingPieces: 0),
      );
    });

    test('a confirmed movement goes straight to the confirmed balance',
        () async {
      await dao.recordMovement(
        stockItemId: stockItemId,
        type: MovementType.opening,
        deltaPieces: 50,
        idempotencyKey: 'open-1',
        syncState: SyncState.confirmed,
      );
      expect(
        await dao.readStoredBalances(stockItemId),
        const LedgerBalances(confirmedPieces: 50, pendingPieces: 0),
      );
      expect(await dao.reconcile(stockItemId), isTrue);
    });

    test('a movement driving the confirmed balance negative is rejected with '
        'no side effects (Req 21.19)', () async {
      await dao.recordMovement(
        stockItemId: stockItemId,
        type: MovementType.opening,
        deltaPieces: 20,
        idempotencyKey: 'open-1',
        syncState: SyncState.confirmed,
      );

      // Attempt a reversal of 25 pieces → would be -5. Must abort wholesale.
      await expectLater(
        dao.recordMovement(
          stockItemId: stockItemId,
          type: MovementType.reverse,
          deltaPieces: -25,
          idempotencyKey: 'rev-1',
          syncState: SyncState.confirmed,
          reason: 'undo mistake',
        ),
        throwsA(isA<NegativeBalanceException>()),
      );

      // Balance unchanged and no movement row was written.
      expect(
        await dao.readStoredBalances(stockItemId),
        const LedgerBalances(confirmedPieces: 20, pendingPieces: 0),
      );
      final movements = await (db.select(db.stockMovements)
            ..where((m) => m.idempotencyKey.equals('rev-1')))
          .get();
      expect(movements, isEmpty);
      expect(await dao.reconcile(stockItemId), isTrue);
    });

    test('a duplicate idempotency key applies the stock effect exactly once '
        '(Requirements 5.9, 19.9)', () async {
      final first = await dao.recordMovement(
        stockItemId: stockItemId,
        type: MovementType.receive,
        deltaPieces: 10,
        idempotencyKey: 'dup-key',
        syncState: SyncState.confirmed,
      );
      final second = await dao.recordMovement(
        stockItemId: stockItemId,
        type: MovementType.receive,
        deltaPieces: 10,
        idempotencyKey: 'dup-key',
        syncState: SyncState.confirmed,
      );

      expect(first, MovementOutcome.applied);
      expect(second, MovementOutcome.duplicateIgnored);

      // Stock added exactly once.
      expect(
        await dao.readStoredBalances(stockItemId),
        const LedgerBalances(confirmedPieces: 10, pendingPieces: 0),
      );
      final movements = await (db.select(db.stockMovements)
            ..where((m) => m.idempotencyKey.equals('dup-key')))
          .get();
      expect(movements, hasLength(1));
      expect(await dao.reconcile(stockItemId), isTrue);
    });

    test('adjust/reverse without a reason is rejected before any write',
        () async {
      await expectLater(
        dao.recordMovement(
          stockItemId: stockItemId,
          type: MovementType.adjust,
          deltaPieces: 5,
          idempotencyKey: 'adj-noreason',
          syncState: SyncState.confirmed,
        ),
        throwsA(isA<ArgumentError>()),
      );
      final movements = await db.select(db.stockMovements).get();
      expect(movements, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Property 22: Balance reconciles with the movement ledger.
  // ---------------------------------------------------------------------------

  /// Generator for a list of movement steps. Each step is a `_Step` describing
  /// a receive (pending or confirmed) or a confirmed adjustment.
  final steps = any.list(
    any.combine3(
      any.bool, // isReceive
      any.bool, // pending (only used for receives)
      any.intInRange(1, 40), // magnitude 1..39
      _Step.new,
    ),
  );

  Glados<List<_Step>>(
    steps,
    ExploreConfig(numRuns: 200, random: Random(20240517)),
  ).test(
    'Feature: wood-cft-app, Property 22: Balance reconciles with the movement '
    'ledger — maintained confirmed/pending balances equal the signed sum of '
    'the ledger after any mix of movements (Requirements 5.13, 6.2)',
    (List<_Step> stepList) async {
      final db = openInMemoryDatabase();
      final dao = StockLedgerDao(db);
      try {
        final stockItemId = await _seedStockItem(db);
        var key = 0;

        for (final step in stepList) {
          final isReceive = step.isReceive;
          final pending = step.pending;
          final mag = step.magnitude;
          key++;

          if (isReceive) {
            // Receives are always non-negative inbound stock, so they never
            // trip the negative guard regardless of pending/confirmed.
            await dao.recordMovement(
              stockItemId: stockItemId,
              type: MovementType.receive,
              deltaPieces: mag,
              idempotencyKey: 'k$key',
              syncState: pending ? SyncState.pending : SyncState.confirmed,
            );
          } else {
            // Confirmed adjustment: subtract, but only to the extent the
            // current confirmed balance allows (so the guard is not expected
            // to fire here). A zero delta is skipped.
            final stored = await dao.readStoredBalances(stockItemId);
            final delta = -(mag % (stored.confirmedPieces + 1));
            if (delta == 0) continue;
            await dao.recordMovement(
              stockItemId: stockItemId,
              type: MovementType.adjust,
              deltaPieces: delta,
              idempotencyKey: 'k$key',
              syncState: SyncState.confirmed,
              reason: 'property adjustment',
            );
          }

          // Invariant must hold after EVERY step: stored == signed sum.
          final stored = await dao.readStoredBalances(stockItemId);
          final fromLedger = await dao.computeBalancesFromLedger(stockItemId);
          expect(stored, fromLedger);
          // Confirmed availability never goes negative.
          expect(stored.confirmedPieces, greaterThanOrEqualTo(0));
        }

        expect(await dao.reconcile(stockItemId), isTrue);
      } finally {
        await db.close();
      }
    },
  );
}
