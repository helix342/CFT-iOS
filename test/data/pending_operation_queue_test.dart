/// Tests for the durable pending-operation queue repository (task 3.3).
///
/// These boot an in-memory [AppDatabase] (so they run under `flutter test` on
/// Windows with no device) and exercise the queue persistence + ordered read +
/// state-transition primitives:
///
///   * enqueue persists a [PendingOperations] row;
///   * a duplicate `idempotency_key` is enqueued exactly once (no-op), and the
///     enqueue composes into a caller-provided transaction atomically;
///   * ordered drain returns rows in enqueue order;
///   * state transitions pending -> confirmed and pending -> failed(lastError)
///     and the attempts counter work.
///
/// Design: design.md -> Data Models (PendingOperation); Transaction Boundaries
/// & Sync (Sync engine). Requirements 5.6, 19.7.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/pending_operation_queue.dart';
import 'package:wood_cft/data/tables.dart';

void main() {
  late AppDatabase db;
  late PendingOperationQueue queue;

  setUp(() {
    db = openInMemoryDatabase();
    queue = PendingOperationQueue(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('enqueue persists a pending-operation row', () async {
    final id = await queue.enqueue(
      opType: OpType.receiveEntry,
      payload: '{"stock":1}',
      idempotencyKey: 'op-1',
      enqueuedAt: DateTime.utc(2024, 1, 1, 10),
    );

    final rows = await db.select(db.pendingOperations).get();
    expect(rows, hasLength(1));

    final row = rows.single;
    expect(row.id, id);
    expect(row.opType, OpType.receiveEntry);
    expect(row.payload, '{"stock":1}');
    expect(row.idempotencyKey, 'op-1');
    expect(row.syncState, SyncState.pending);
    expect(row.attempts, 0);
    expect(row.lastError, isNull);
    // The persisted instant round-trips (drift stores Unix epoch; the read
    // back value represents the same moment regardless of its zone flag).
    expect(
      row.enqueuedAt.isAtSameMomentAs(DateTime.utc(2024, 1, 1, 10)),
      isTrue,
    );
  });

  test('a duplicate idempotency key is enqueued exactly once (no-op)', () async {
    final first = await queue.enqueue(
      opType: OpType.receiveEntry,
      payload: 'first',
      idempotencyKey: 'dup',
      enqueuedAt: DateTime.utc(2024, 1, 1, 10),
    );

    // Same key again (a retry / double-tap / resume) must not create a second
    // row and must not overwrite the first row's payload.
    final second = await queue.enqueue(
      opType: OpType.adjust,
      payload: 'second',
      idempotencyKey: 'dup',
      enqueuedAt: DateTime.utc(2024, 1, 1, 11),
    );

    expect(second, first, reason: 'duplicate enqueue returns the surviving id');

    final rows = await db.select(db.pendingOperations).get();
    expect(rows, hasLength(1));
    // The surviving row is the first one, unchanged.
    expect(rows.single.payload, 'first');
    expect(rows.single.opType, OpType.receiveEntry);
  });

  test('enqueue composes into a caller transaction and is atomic', () async {
    // The enqueue runs inside the caller's transaction. When the transaction
    // rolls back, the enqueued row must not persist (atomic with the local
    // write that task 5.1 performs in the same transaction).
    await expectLater(
      db.transaction(() async {
        await queue.enqueue(
          opType: OpType.receiveEntry,
          payload: 'in-txn',
          idempotencyKey: 'txn-op',
          enqueuedAt: DateTime.utc(2024, 1, 1, 10),
          executor: db,
        );
        // Force the transaction to roll back.
        throw _RollbackSignal();
      }),
      throwsA(isA<_RollbackSignal>()),
    );

    final rows = await db.select(db.pendingOperations).get();
    expect(rows, isEmpty, reason: 'rolled-back enqueue leaves no row');

    // A committed transaction persists the enqueue.
    await db.transaction(() async {
      await queue.enqueue(
        opType: OpType.receiveEntry,
        payload: 'committed',
        idempotencyKey: 'txn-op-2',
        enqueuedAt: DateTime.utc(2024, 1, 1, 10),
        executor: db,
      );
    });

    final committed = await db.select(db.pendingOperations).get();
    expect(committed, hasLength(1));
    expect(committed.single.idempotencyKey, 'txn-op-2');
  });

  test('ordered drain returns pending rows in enqueue order', () async {
    // Enqueue out of chronological order to prove ordering is by enqueuedAt,
    // not by insert order.
    await queue.enqueue(
      opType: OpType.receiveEntry,
      payload: 'c',
      idempotencyKey: 'c',
      enqueuedAt: DateTime.utc(2024, 1, 1, 12),
    );
    await queue.enqueue(
      opType: OpType.receiveEntry,
      payload: 'a',
      idempotencyKey: 'a',
      enqueuedAt: DateTime.utc(2024, 1, 1, 10),
    );
    await queue.enqueue(
      opType: OpType.receiveEntry,
      payload: 'b',
      idempotencyKey: 'b',
      enqueuedAt: DateTime.utc(2024, 1, 1, 11),
    );

    final ordered = await queue.readPendingInOrder();
    expect(ordered.map((r) => r.payload).toList(), ['a', 'b', 'c']);
  });

  test('ties on enqueuedAt break by ascending id', () async {
    final sameTime = DateTime.utc(2024, 1, 1, 10);
    final id1 = await queue.enqueue(
      opType: OpType.receiveEntry,
      payload: 'first',
      idempotencyKey: 'k1',
      enqueuedAt: sameTime,
    );
    final id2 = await queue.enqueue(
      opType: OpType.receiveEntry,
      payload: 'second',
      idempotencyKey: 'k2',
      enqueuedAt: sameTime,
    );

    final ordered = await queue.readPendingInOrder();
    expect(ordered.map((r) => r.id).toList(), [id1, id2]);
  });

  test('readPendingInOrder excludes confirmed and failed rows', () async {
    final pendingId = await queue.enqueue(
      opType: OpType.receiveEntry,
      payload: 'pending',
      idempotencyKey: 'p',
      enqueuedAt: DateTime.utc(2024, 1, 1, 10),
    );
    final confirmedId = await queue.enqueue(
      opType: OpType.receiveEntry,
      payload: 'confirmed',
      idempotencyKey: 'c',
      enqueuedAt: DateTime.utc(2024, 1, 1, 11),
    );
    final failedId = await queue.enqueue(
      opType: OpType.receiveEntry,
      payload: 'failed',
      idempotencyKey: 'f',
      enqueuedAt: DateTime.utc(2024, 1, 1, 12),
    );

    await queue.markConfirmed(confirmedId);
    await queue.markFailed(failedId, 'rejected');

    final pending = await queue.readPendingInOrder();
    expect(pending.map((r) => r.id).toList(), [pendingId]);
  });

  test('state transition pending -> confirmed', () async {
    final id = await queue.enqueue(
      opType: OpType.receiveEntry,
      payload: 'x',
      idempotencyKey: 'confirm-me',
      enqueuedAt: DateTime.utc(2024, 1, 1, 10),
    );

    final updated = await queue.markConfirmed(id);
    expect(updated, 1);

    final row = await queue.findByIdempotencyKey('confirm-me');
    expect(row, isNotNull);
    expect(row!.syncState, SyncState.confirmed);
    expect(row.lastError, isNull);
  });

  test('state transition pending -> failed records lastError', () async {
    final id = await queue.enqueue(
      opType: OpType.finalize,
      payload: 'x',
      idempotencyKey: 'fail-me',
      enqueuedAt: DateTime.utc(2024, 1, 1, 10),
    );

    final updated = await queue.markFailed(id, 'server rejected: 409');
    expect(updated, 1);

    final row = await queue.findByIdempotencyKey('fail-me');
    expect(row, isNotNull);
    expect(row!.syncState, SyncState.failed);
    expect(row.lastError, 'server rejected: 409');
  });

  test('incrementAttempts increments and returns the new count', () async {
    final id = await queue.enqueue(
      opType: OpType.receiveEntry,
      payload: 'x',
      idempotencyKey: 'attempt-me',
      enqueuedAt: DateTime.utc(2024, 1, 1, 10),
    );

    expect(await queue.incrementAttempts(id), 1);
    expect(await queue.incrementAttempts(id), 2);

    final row = await queue.findByIdempotencyKey('attempt-me');
    expect(row!.attempts, 2);

    // Unknown id is a no-op returning null.
    expect(await queue.incrementAttempts(999999), isNull);
  });
}

/// Thrown inside a transaction body to force a rollback in tests.
class _RollbackSignal implements Exception {}
