/// Opening-stock, adjustment, and reversal/undo service (task 5.4).
///
/// [StockAdjustmentService] drives the **local-only adjustment/reversal**
/// boundary from design.md -> Transaction Boundaries & Sync (local-only b),
/// plus the opening-stock entry path. It is a headless application-layer
/// service over the data layer (`StockLedgerDao` + `PendingOperationQueue`);
/// it drives no Cupertino UI and is fully testable against an in-memory
/// database.
///
/// Three operations, each one atomic local write that composes the ledger
/// append and the queue enqueue into ONE drift transaction:
///
///   * **Opening stock** (`recordOpeningStock`) — appends a
///     `MovementType.opening` movement with `sync_state = Pending`, so the
///     quantity lands in `pending_balance_pieces` as `Pending_Receiving_Stock`
///     and is not sellable until the sync engine confirms it (5.10, 5.6a,
///     19.8). Opening stock is still a real stock movement with history
///     (5.13) — it is never a silent balance poke.
///   * **Adjustment** (`recordAdjustment`) — appends a `MovementType.adjust`
///     movement (`sync_state = Confirmed`) with a REQUIRED reason (5.10). The
///     signed delta adjusts the confirmed (sellable) balance directly. A
///     negative delta that would drive confirmed availability below zero is
///     blocked by the ledger's negative-availability guard (5.12, 21.19).
///   * **Reversal / undo** (`recordReversal`) — appends a
///     `MovementType.reverse` movement (`sync_state = Confirmed`) with a
///     REQUIRED reason (5.11). Undo of a prior entry is expressed as a
///     reversal movement; it never hard-deletes the original row, so the full
///     movement history is retained (5.13). If reversing a prior inbound entry
///     would drive confirmed availability negative (because that stock has
///     since been sold), the whole transaction aborts with no side effects and
///     a blocking [NegativeBalanceException] is surfaced (5.12, 21.19).
///
/// ### Negative-availability guard (design.md -> Error Handling)
///
/// Adjustments and reversals that would make a stock item's available quantity
/// negative abort the whole local transaction and surface a blocking error.
/// The guard lives in [StockLedgerDao.recordMovement]; this service lets the
/// [NegativeBalanceException] propagate so the caller can present a clear
/// conflict message, and because the ledger append and the queue enqueue share
/// one transaction, a blocked movement leaves the balance unchanged AND never
/// enqueues an op (Property 20; 5.12, 21.19).
///
/// ### Exactly-once (idempotent, retry-safe)
///
/// Every operation carries a stable `idempotency_key`. The ledger movement
/// (unique key) and the pending-op queue row (unique key) both key off it, so
/// a retry/double-tap re-presents the same key and is a no-op — the stock
/// effect applies exactly once (5.9, 19.9).
library;

import 'package:meta/meta.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/pending_operation_queue.dart';
import 'package:wood_cft/data/stock_ledger_dao.dart';
import 'package:wood_cft/data/tables.dart';

/// The outcome of recording an opening/adjustment/reversal entry.
enum StockAdjustmentOutcome {
  /// The movement was recorded: a `StockMovements` row and a
  /// `PendingOperations` row were written in one transaction and the balance
  /// was updated.
  recorded,

  /// The idempotency key already existed; the call was a no-op so the effect
  /// applies exactly once (5.9, 19.9).
  duplicateIgnored,
}

/// The result of recording an opening/adjustment/reversal entry.
@immutable
class StockAdjustmentResult {
  /// Creates a result.
  const StockAdjustmentResult({
    required this.outcome,
    required this.movementType,
    required this.deltaPieces,
  });

  /// Whether the entry was newly recorded or ignored as a duplicate.
  final StockAdjustmentOutcome outcome;

  /// The movement type that was (or would have been) recorded.
  final MovementType movementType;

  /// The signed whole-piece delta the entry represents.
  final int deltaPieces;

  @override
  String toString() =>
      'StockAdjustmentResult(outcome: $outcome, movementType: $movementType, '
      'deltaPieces: $deltaPieces)';
}

/// Drives opening-stock entry and adjustment/reversal with the
/// negative-stock guard and undo (task 5.4).
class StockAdjustmentService {
  /// Creates a stock-adjustment service over [_db].
  StockAdjustmentService(this._db)
      : _ledger = StockLedgerDao(_db),
        _queue = PendingOperationQueue(_db);

  final AppDatabase _db;
  final StockLedgerDao _ledger;
  final PendingOperationQueue _queue;

  /// Records an opening-stock entry for [stockItemId] as one atomic local
  /// write (design.md -> local-only a; 5.10).
  ///
  /// Appends a `MovementType.opening` movement with `sync_state = Pending`
  /// (incrementing the PENDING balance, so the quantity shows as
  /// `Pending_Receiving_Stock` and is not sellable until synced — 5.6a, 19.8)
  /// and enqueues the matching pending op in the SAME transaction. Opening
  /// stock is a real movement, so the history is retained (5.13).
  ///
  /// [openingPieces] must be a positive whole-piece count. Repeating the same
  /// [idempotencyKey] is a no-op returning [StockAdjustmentOutcome.duplicateIgnored]
  /// (5.9).
  Future<StockAdjustmentResult> recordOpeningStock({
    required int stockItemId,
    required int openingPieces,
    required String idempotencyKey,
    DateTime? occurredAt,
  }) async {
    if (openingPieces <= 0) {
      throw ArgumentError.value(
        openingPieces,
        'openingPieces',
        'opening stock must be a positive whole number of pieces',
      );
    }
    return _record(
      stockItemId: stockItemId,
      type: MovementType.opening,
      deltaPieces: openingPieces,
      syncState: SyncState.pending,
      idempotencyKey: idempotencyKey,
      occurredAt: occurredAt,
    );
  }

  /// Records a stock adjustment for [stockItemId] as one atomic local write
  /// (design.md -> local-only b; 5.10, 5.11).
  ///
  /// [deltaPieces] is a signed whole-piece correction applied to the CONFIRMED
  /// (sellable) balance; [reason] is REQUIRED and must be non-empty (5.10). A
  /// negative [deltaPieces] that would drive confirmed availability below zero
  /// is blocked by the negative-availability guard: the whole transaction
  /// aborts, nothing is enqueued, the balance is unchanged, and a
  /// [NegativeBalanceException] is thrown (5.12, 21.19).
  ///
  /// Repeating the same [idempotencyKey] is a no-op returning
  /// [StockAdjustmentOutcome.duplicateIgnored] (5.9).
  Future<StockAdjustmentResult> recordAdjustment({
    required int stockItemId,
    required int deltaPieces,
    required String reason,
    required String idempotencyKey,
    DateTime? occurredAt,
  }) async {
    if (deltaPieces == 0) {
      throw ArgumentError.value(
        deltaPieces,
        'deltaPieces',
        'an adjustment must change the balance by a non-zero amount',
      );
    }
    return _record(
      stockItemId: stockItemId,
      type: MovementType.adjust,
      deltaPieces: deltaPieces,
      syncState: SyncState.confirmed,
      idempotencyKey: idempotencyKey,
      reason: reason,
      occurredAt: occurredAt,
    );
  }

  /// Records a reversal/undo of a prior committed entry for [stockItemId] as
  /// one atomic local write (design.md -> local-only b; 5.11).
  ///
  /// [deltaPieces] is the signed whole-piece delta that reverses the prior
  /// entry (e.g. to undo a `+30` inbound entry pass `-30`); [reason] is
  /// REQUIRED and must be non-empty. The reversal is recorded as a
  /// `MovementType.reverse` movement — the original row is NEVER hard-deleted,
  /// so the full movement history is retained (5.13).
  ///
  /// If the reversal would drive confirmed availability below zero (the stock
  /// being undone has since been sold), the whole transaction aborts with no
  /// side effects and a blocking [NegativeBalanceException] is thrown; the
  /// balance stays unchanged and nothing is enqueued (5.12, 21.19).
  ///
  /// Repeating the same [idempotencyKey] is a no-op returning
  /// [StockAdjustmentOutcome.duplicateIgnored] (5.9).
  Future<StockAdjustmentResult> recordReversal({
    required int stockItemId,
    required int deltaPieces,
    required String reason,
    required String idempotencyKey,
    DateTime? occurredAt,
  }) async {
    if (deltaPieces == 0) {
      throw ArgumentError.value(
        deltaPieces,
        'deltaPieces',
        'a reversal must change the balance by a non-zero amount',
      );
    }
    return _record(
      stockItemId: stockItemId,
      type: MovementType.reverse,
      deltaPieces: deltaPieces,
      syncState: SyncState.confirmed,
      idempotencyKey: idempotencyKey,
      reason: reason,
      occurredAt: occurredAt,
    );
  }

  /// Shared atomic path: append the signed movement via [StockLedgerDao] and,
  /// only if it was newly applied, enqueue the matching pending op — both in
  /// ONE transaction.
  ///
  /// The ledger enforces the required `reason` for adjust/reverse and the
  /// negative-availability guard; a thrown [NegativeBalanceException] or
  /// [ArgumentError] rolls the whole transaction back (no movement, no
  /// enqueue, balance unchanged). A duplicate idempotency key short-circuits to
  /// a no-op before any enqueue (5.9).
  Future<StockAdjustmentResult> _record({
    required int stockItemId,
    required MovementType type,
    required int deltaPieces,
    required SyncState syncState,
    required String idempotencyKey,
    String? reason,
    DateTime? occurredAt,
  }) async {
    final occurred = (occurredAt ?? DateTime.now()).toUtc();

    return _db.transaction(() async {
      final movementOutcome = await _ledger.recordMovement(
        stockItemId: stockItemId,
        type: type,
        deltaPieces: deltaPieces,
        idempotencyKey: idempotencyKey,
        syncState: syncState,
        reason: reason,
        occurredAt: occurred,
      );

      if (movementOutcome == MovementOutcome.duplicateIgnored) {
        // Exactly-once: the movement already exists, so do not re-enqueue.
        return StockAdjustmentResult(
          outcome: StockAdjustmentOutcome.duplicateIgnored,
          movementType: type,
          deltaPieces: deltaPieces,
        );
      }

      // Enqueue the pending op in the SAME transaction so the local write +
      // enqueue commit atomically (5.6, 19.7). Opening stock reuses the
      // receive-entry op type (it is an inbound receiving movement); manual
      // adjustments/reversals use the adjust op type.
      final opType = type == MovementType.opening
          ? OpType.receiveEntry
          : OpType.adjust;
      await _queue.enqueue(
        opType: opType,
        payload: _payload(
          stockItemId: stockItemId,
          type: type,
          deltaPieces: deltaPieces,
        ),
        idempotencyKey: idempotencyKey,
        enqueuedAt: occurred,
        executor: _db,
      );

      return StockAdjustmentResult(
        outcome: StockAdjustmentOutcome.recorded,
        movementType: type,
        deltaPieces: deltaPieces,
      );
    });
  }

  /// Builds the durable queue payload. Kept minimal and stable: the sync
  /// engine (task 4.3) re-applies the movement by its own idempotency key, so
  /// the payload only needs to identify the local write.
  String _payload({
    required int stockItemId,
    required MovementType type,
    required int deltaPieces,
  }) {
    return '{"kind":"${type.name}",'
        '"stockItemId":$stockItemId,'
        '"deltaPieces":$deltaPieces}';
  }
}
