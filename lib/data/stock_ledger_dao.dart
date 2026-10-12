/// The movement ledger with a transactionally-maintained balance and the
/// reconciliation invariant (task 3.2).
///
/// [StockLedgerDao] is the pure data-layer entry point for appending signed
/// `StockMovements` rows and keeping the owning `StockItems` balances in sync.
/// It implements the design's **reconciliation invariant** (design.md -> Data
/// Models): the maintained balance is a *cache* of the signed sum of the
/// ledger, and the ledger is the source of truth.
///
/// Responsibilities (design.md -> Data Models; Transaction Boundaries & Sync):
///
///   * **Atomic append.** Each `recordMovement` call inserts one signed
///     `StockMovements` row AND updates the owning `StockItems` balance inside
///     ONE local drift transaction — all-or-nothing.
///   * **Pending vs confirmed split** ("Local cache vs hosted schema"):
///       - `confirmed_balance_pieces` = signed sum of CONFIRMED movements;
///       - `pending_balance_pieces`   = signed sum of not-yet-confirmed
///         RECEIVE / OPENING movements.
///     A pending receive adds to the pending balance; `confirmMovement` moves
///     that delta from pending -> confirmed.
///   * **Negative-availability guard** (5.12, 21.19): a movement that would
///     drive the CONFIRMED available balance negative is rejected and the
///     whole transaction aborts with no side effects.
///   * **Idempotency** (5.9, 19.9): inserting a movement whose
///     `idempotency_key` already exists is a no-op — the stock effect applies
///     exactly once. This relies on the unique constraint plus a
///     catch/no-op.
///   * **Reconciliation check** (`reconcile`): recomputes both balances from
///     the ledger so callers / tests can assert the invariant holds.
///
/// This is strictly the data layer. It does NOT drain the pending-op queue
/// (task 3.3) nor drive any receiving UI (task 5.x); it only reads and writes
/// the `StockMovements` / `StockItems` tables.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:meta/meta.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/tables.dart';

/// Thrown when a movement would drive the CONFIRMED available balance of a
/// stock item negative. The enclosing transaction is rolled back, so the
/// movement is never inserted and no balance changes (5.12, 21.19).
class NegativeBalanceException implements Exception {
  /// Creates the exception for [stockItemId], recording the balance that would
  /// have resulted had the guard not fired.
  const NegativeBalanceException({
    required this.stockItemId,
    required this.attemptedConfirmedBalance,
  });

  /// The stock item whose confirmed balance would have gone negative.
  final int stockItemId;

  /// The negative confirmed balance that was rejected.
  final int attemptedConfirmedBalance;

  @override
  String toString() =>
      'NegativeBalanceException(stockItemId: $stockItemId, '
      'attemptedConfirmedBalance: $attemptedConfirmedBalance)';
}

/// The outcome of attempting to record a movement.
enum MovementOutcome {
  /// The movement was inserted and balances were updated.
  applied,

  /// The idempotency key already existed; the call was a no-op (exactly once).
  duplicateIgnored,
}

/// A pair of maintained balances for a stock item.
@immutable
class LedgerBalances {
  /// Creates a balance pair.
  const LedgerBalances({
    required this.confirmedPieces,
    required this.pendingPieces,
  });

  /// Signed sum of CONFIRMED movements (the sellable quantity).
  final int confirmedPieces;

  /// Signed sum of not-yet-confirmed RECEIVE / OPENING movements (display-only).
  final int pendingPieces;

  @override
  bool operator ==(Object other) =>
      other is LedgerBalances &&
      other.confirmedPieces == confirmedPieces &&
      other.pendingPieces == pendingPieces;

  @override
  int get hashCode => Object.hash(confirmedPieces, pendingPieces);

  @override
  String toString() =>
      'LedgerBalances(confirmed: $confirmedPieces, pending: $pendingPieces)';
}

/// The movement types that contribute to the *pending* balance while a
/// movement is still `SyncState.pending`. Only inbound receiving/opening stock
/// is shown as `Pending_Receiving_Stock` (design.md -> "Local cache vs hosted
/// schema"; 5.6a, 19.8). Every other movement type takes effect only once it is
/// confirmed.
bool _countsTowardPending(MovementType type) =>
    type == MovementType.receive || type == MovementType.opening;

/// Appends signed movements and maintains the `StockItems` balances so they
/// always equal the signed sum of the `StockMovements` ledger.
class StockLedgerDao {
  /// Creates a ledger DAO over [_db].
  StockLedgerDao(this._db);

  final AppDatabase _db;

  /// Records a signed `StockMovements` row for [stockItemId] and updates the
  /// owning `StockItems` balance inside ONE local transaction.
  ///
  /// Behaviour:
  ///   * A `pending` RECEIVE/OPENING movement increments
  ///     `pending_balance_pieces` by [deltaPieces]; every other case adjusts
  ///     `confirmed_balance_pieces`.
  ///   * If the resulting CONFIRMED balance would be negative, the whole
  ///     transaction is rolled back and [NegativeBalanceException] is thrown
  ///     (5.12, 21.19). Pending receives never fail this guard because they
  ///     only add inbound stock.
  ///   * If [idempotencyKey] already exists, the call is a no-op and returns
  ///     [MovementOutcome.duplicateIgnored] (5.9, 19.9).
  ///
  /// [reason] is required for [MovementType.adjust] and [MovementType.reverse]
  /// (design.md -> StockMovement.reason); passing null for those types throws
  /// an [ArgumentError] before any write.
  Future<MovementOutcome> recordMovement({
    required int stockItemId,
    required MovementType type,
    required int deltaPieces,
    required String idempotencyKey,
    required SyncState syncState,
    DateTime? occurredAt,
    String? reason,
    int? receiptEntryId,
    int? invoiceId,
  }) async {
    if ((type == MovementType.adjust || type == MovementType.reverse) &&
        (reason == null || reason.trim().isEmpty)) {
      throw ArgumentError.value(
        reason,
        'reason',
        'A reason is required for Adjust/Reverse movements',
      );
    }

    final occurred = (occurredAt ?? DateTime.now()).toUtc();
    final toPending = syncState == SyncState.pending && _countsTowardPending(type);

    return _db.transaction(() async {
      // Idempotency: a movement with an existing key is applied exactly once.
      // The unique constraint on `idempotency_key` is the source of truth; we
      // probe first (cheap, keeps the transaction clean) and still catch the
      // constraint violation in case of a race.
      final existing =
          await (_db.select(_db.stockMovements)
                ..where((m) => m.idempotencyKey.equals(idempotencyKey)))
              .get();
      if (existing.isNotEmpty) {
        return MovementOutcome.duplicateIgnored;
      }

      final item = await (_db.select(_db.stockItems)
            ..where((s) => s.id.equals(stockItemId)))
          .getSingle();

      // Compute the resulting balance. Pending receive/opening stock lands in
      // the pending bucket; everything else moves the confirmed balance.
      var confirmed = item.confirmedBalancePieces;
      var pending = item.pendingBalancePieces;
      if (toPending) {
        pending += deltaPieces;
      } else {
        confirmed += deltaPieces;
      }

      // Negative-availability guard: never let CONFIRMED availability go below
      // zero. Abort the whole transaction with no side effects (5.12, 21.19).
      if (confirmed < 0) {
        throw NegativeBalanceException(
          stockItemId: stockItemId,
          attemptedConfirmedBalance: confirmed,
        );
      }

      try {
        await _db.into(_db.stockMovements).insert(
              StockMovementsCompanion.insert(
                stockItemId: stockItemId,
                type: type,
                deltaPieces: deltaPieces,
                occurredAt: occurred,
                idempotencyKey: idempotencyKey,
                syncState: syncState,
                reason: Value(reason),
                receiptEntryId: Value(receiptEntryId),
                invoiceId: Value(invoiceId),
              ),
            );
      } on SqliteException {
        // A concurrent insert won the unique-key race: treat as a no-op so the
        // effect still applies exactly once.
        return MovementOutcome.duplicateIgnored;
      }

      await (_db.update(_db.stockItems)..where((s) => s.id.equals(stockItemId)))
          .write(
        StockItemsCompanion(
          confirmedBalancePieces: Value(confirmed),
          pendingBalancePieces: Value(pending),
        ),
      );

      return MovementOutcome.applied;
    });
  }

  /// Confirms a previously-pending movement: flips its `sync_state` to
  /// [SyncState.confirmed] and, for RECEIVE/OPENING movements, moves its delta
  /// from `pending_balance_pieces` to `confirmed_balance_pieces` inside one
  /// transaction (design.md -> Sync engine).
  ///
  /// A movement that is not currently pending is left unchanged (idempotent).
  Future<void> confirmMovement(String idempotencyKey) async {
    await _db.transaction(() async {
      final movements = await (_db.select(_db.stockMovements)
            ..where((m) => m.idempotencyKey.equals(idempotencyKey)))
          .get();
      if (movements.isEmpty) return;
      final movement = movements.single;
      if (movement.syncState != SyncState.pending) return;

      await (_db.update(_db.stockMovements)
            ..where((m) => m.id.equals(movement.id)))
          .write(const StockMovementsCompanion(
        syncState: Value(SyncState.confirmed),
      ));

      // Only receive/opening deltas were parked in the pending bucket; move
      // them to confirmed. Other movement types already affected confirmed.
      if (_countsTowardPending(movement.type)) {
        final item = await (_db.select(_db.stockItems)
              ..where((s) => s.id.equals(movement.stockItemId)))
            .getSingle();
        await (_db.update(_db.stockItems)
              ..where((s) => s.id.equals(movement.stockItemId)))
            .write(
          StockItemsCompanion(
            confirmedBalancePieces:
                Value(item.confirmedBalancePieces + movement.deltaPieces),
            pendingBalancePieces:
                Value(item.pendingBalancePieces - movement.deltaPieces),
          ),
        );
      }
    });
  }

  /// Recomputes both balances for [stockItemId] directly from the ledger.
  ///
  /// This is the authoritative reconciliation computation: the confirmed
  /// balance is the signed sum of CONFIRMED movements, and the pending balance
  /// is the signed sum of not-yet-confirmed RECEIVE/OPENING movements
  /// (design.md -> reconciliation invariant). Failed movements never count.
  Future<LedgerBalances> computeBalancesFromLedger(int stockItemId) async {
    final movements = await (_db.select(_db.stockMovements)
          ..where((m) => m.stockItemId.equals(stockItemId)))
        .get();

    var confirmed = 0;
    var pending = 0;
    for (final m in movements) {
      switch (m.syncState) {
        case SyncState.confirmed:
          confirmed += m.deltaPieces;
        case SyncState.pending:
          if (_countsTowardPending(m.type)) {
            pending += m.deltaPieces;
          }
        case SyncState.failed:
          // Rejected movements never contribute to either balance.
          break;
      }
    }
    return LedgerBalances(confirmedPieces: confirmed, pendingPieces: pending);
  }

  /// Reads the maintained (cached) balances stored on the `StockItems` row.
  Future<LedgerBalances> readStoredBalances(int stockItemId) async {
    final item = await (_db.select(_db.stockItems)
          ..where((s) => s.id.equals(stockItemId)))
        .getSingle();
    return LedgerBalances(
      confirmedPieces: item.confirmedBalancePieces,
      pendingPieces: item.pendingBalancePieces,
    );
  }

  /// Returns true when the maintained balances for [stockItemId] equal the
  /// signed sum of its ledger (the reconciliation invariant holds).
  Future<bool> reconcile(int stockItemId) async {
    final stored = await readStoredBalances(stockItemId);
    final fromLedger = await computeBalancesFromLedger(stockItemId);
    return stored == fromLedger;
  }
}
