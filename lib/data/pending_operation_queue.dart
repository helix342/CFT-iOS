/// The durable pending-operation queue repository (task 3.3).
///
/// [PendingOperationQueue] is the data-layer owner of the [PendingOperations]
/// table declared in `tables.dart`. It provides the *persistence + ordered
/// read + state-transition primitives* that the sync engine (task 4.3,
/// `SyncService`) and the receiving flow (task 5.1, `ReceivingService`) build
/// on. It deliberately does NOT implement the hosted-DB apply/drain loop with
/// backoff — that behavior lives in `SyncService`.
///
/// Design references:
///   * design.md -> Data Models (PendingOperation) — the queue row shape and
///     its unique `idempotency_key`;
///   * design.md -> Transaction Boundaries & Sync (Sync engine) — the queue
///     "drains in enqueue order" and each op is applied exactly once under its
///     idempotency key.
///
/// Requirements: 5.6 (only confirmed stock is sellable — the queue carries the
/// pending op that must sync before stock becomes sellable) and 19.7 (local
/// write is enqueued with a stable idempotency key).
///
/// ### Atomic enqueue within a caller transaction
///
/// `enqueue` accepts an optional `executor`. When the receiving flow (task 5.1)
/// writes a local movement and enqueues the matching pending op, it passes the
/// surrounding transaction handle so the enqueue composes into that single
/// outer transaction — either both the local write and the enqueue commit, or
/// neither does. When no executor is supplied the enqueue runs directly against
/// the database.
///
/// ### Exactly-once enqueue
///
/// The `idempotency_key` column is `unique`. `enqueue` inserts with an
/// *insert-or-ignore* conflict policy, so re-enqueuing the same key (a retry, a
/// double-tap, a resumed/finished receipt) is a **no-op**: the first row stays
/// as it was and no duplicate is created. `enqueue` returns the id of the
/// surviving row, so callers always get the single canonical queue entry.
library;

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/tables.dart';

/// Data-layer repository for the durable pending-operation queue.
class PendingOperationQueue {
  /// Creates a queue repository over [_db].
  PendingOperationQueue(this._db);

  final AppDatabase _db;

  /// The table accessor on the owning database.
  $PendingOperationsTable get _table => _db.pendingOperations;

  /// Enqueues a pending operation, exactly once per [idempotencyKey].
  ///
  /// Pass [executor] to compose this enqueue into a caller-owned outer
  /// transaction so it commits atomically with the caller's local write
  /// (task 5.1). The typical pattern is:
  ///
  /// ```dart
  /// await db.transaction(() async {
  ///   // ... caller's local movement write on `db` ...
  ///   await queue.enqueue(..., executor: db);
  /// });
  /// ```
  ///
  /// Drift routes queries issued on the same [AppDatabase] instance to the
  /// active transaction (zone-based), so passing [executor] (the same database
  /// handle) keeps the enqueue inside the caller's transaction — either both
  /// the local write and the enqueue commit, or neither does. When [executor]
  /// is null the insert runs directly on the database.
  ///
  /// Re-enqueuing an already-present [idempotencyKey] is a no-op (the unique
  /// constraint + insert-or-ignore policy). Returns the id of the surviving
  /// queue row (the newly inserted row, or the pre-existing one on a duplicate).
  Future<int> enqueue({
    required OpType opType,
    required String payload,
    required String idempotencyKey,
    required DateTime enqueuedAt,
    AppDatabase? executor,
  }) async {
    final db = executor ?? _db;
    final table = db.pendingOperations;

    await db
        .into(table)
        .insert(
          PendingOperationsCompanion.insert(
            opType: opType,
            payload: payload,
            idempotencyKey: idempotencyKey,
            enqueuedAt: enqueuedAt.toUtc(),
            syncState: SyncState.pending,
          ),
          // A duplicate idempotency key does nothing — exactly-once enqueue.
          mode: InsertMode.insertOrIgnore,
        );

    // Resolve the surviving row's id (insert-or-ignore does not reliably
    // return a usable rowid on conflict), so callers always get the canonical
    // queue entry regardless of whether this was the first or a duplicate.
    final row =
        await (db.select(table)
              ..where((t) => t.idempotencyKey.equals(idempotencyKey)))
            .getSingle();
    return row.id;
  }

  /// Reads the pending operations that still need to be drained, in **enqueue
  /// order** (ascending `enqueued_at`, then ascending `id` as a stable
  /// tie-breaker). Only rows still in [SyncState.pending] are returned, since
  /// confirmed and failed ops are never re-applied.
  ///
  /// This is the ordered read the sync engine (task 4.3) consumes; the actual
  /// apply/backoff loop is not implemented here.
  Future<List<PendingOperationRow>> readPendingInOrder() {
    return (_db.select(_table)
          ..where((t) => t.syncState.equalsValue(SyncState.pending))
          ..orderBy([
            (t) => OrderingTerm.asc(t.enqueuedAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  /// Reads every queue row in enqueue order, regardless of sync state. Useful
  /// for diagnostics and for surfacing failed ops to the owner.
  Future<List<PendingOperationRow>> readAllInOrder() {
    return (_db.select(_table)
          ..orderBy([
            (t) => OrderingTerm.asc(t.enqueuedAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  /// Looks up a single queue row by its [idempotencyKey], or null if none.
  Future<PendingOperationRow?> findByIdempotencyKey(String idempotencyKey) {
    return (_db.select(_table)
          ..where((t) => t.idempotencyKey.equals(idempotencyKey)))
        .getSingleOrNull();
  }

  /// Transitions a queue row from pending to [SyncState.confirmed] after the
  /// hosted database has acknowledged the operation. Clears any prior error.
  ///
  /// Returns the number of rows updated (0 if [id] does not exist).
  Future<int> markConfirmed(int id) {
    return (_db.update(_table)..where((t) => t.id.equals(id))).write(
      const PendingOperationsCompanion(
        syncState: Value(SyncState.confirmed),
        lastError: Value(null),
      ),
    );
  }

  /// Transitions a queue row to [SyncState.failed] and records [error] in
  /// `last_error`. Failed ops are surfaced to the owner and never promoted.
  ///
  /// Returns the number of rows updated (0 if [id] does not exist).
  Future<int> markFailed(int id, String error) {
    return (_db.update(_table)..where((t) => t.id.equals(id))).write(
      PendingOperationsCompanion(
        syncState: const Value(SyncState.failed),
        lastError: Value(error),
      ),
    );
  }

  /// Increments the `attempts` counter for the row [id] by one and returns the
  /// new attempt count. The sync engine (task 4.3) calls this before each apply
  /// so backoff can be driven off the attempt count.
  ///
  /// Returns null if [id] does not exist.
  Future<int?> incrementAttempts(int id) async {
    final before = await (_db.select(_table)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (before == null) return null;
    final next = before.attempts + 1;
    await (_db.update(_table)..where((t) => t.id.equals(id))).write(
      PendingOperationsCompanion(attempts: Value(next)),
    );
    return next;
  }
}

/// Visible-for-testing helper: the design's enqueue-order comparator, exposed
/// so tests can assert ordering independently of the database.
@visibleForTesting
int comparePendingOrder(PendingOperationRow a, PendingOperationRow b) {
  final byTime = a.enqueuedAt.compareTo(b.enqueuedAt);
  if (byTime != 0) return byTime;
  return a.id.compareTo(b.id);
}
