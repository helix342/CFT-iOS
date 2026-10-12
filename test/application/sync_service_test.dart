/// Unit tests for the sync engine (task 4.3, `SyncService`).
///
/// These boot an in-memory [AppDatabase] (so they run under `flutter test` on
/// Windows with no device), a [FakeAuthService], and a controllable
/// [HostedDatabase] wrapper around [FakeHostedDatabase] that can simulate lost
/// responses, transient failures, and definitive rejections. They verify the
/// design's Sync-engine behaviour (design.md -> Transaction Boundaries & Sync):
///
///   * draining applies pending ops in enqueue order and flips the local
///     movement pending -> confirmed (Requirement 19.8, 19.9);
///   * a lost response retried with the SAME key yields exactly one hosted
///     effect — no duplicate movement (Requirement 19.10, 21.26);
///   * a transient failure retries with (fake) backoff then succeeds;
///   * a permanent rejection marks the op `Failed` and never promotes it;
///   * draining without a session is refused and leaves every op pending
///     (Requirement 19.3).
///
/// Test framework: `package:glados` (re-exports `package:test`), matching the
/// existing data/application tests. The injected clock records requested delays
/// and completes instantly, so backoff never really sleeps.
library;

import 'dart:async';

import 'package:glados/glados.dart';
import 'package:wood_cft/application/auth_service.dart';
import 'package:wood_cft/application/sync_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/hosted_database.dart';
import 'package:wood_cft/data/pending_operation_queue.dart';
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

/// Records a pending RECEIVE movement and enqueues the matching pending op,
/// both keyed by [idempotencyKey], mirroring the receiving flow (task 5.1).
Future<void> _enqueuePendingReceive(
  AppDatabase db, {
  required int stockItemId,
  required int pieces,
  required String idempotencyKey,
  required DateTime enqueuedAt,
}) async {
  final ledger = StockLedgerDao(db);
  final queue = PendingOperationQueue(db);
  await db.transaction(() async {
    await ledger.recordMovement(
      stockItemId: stockItemId,
      type: MovementType.receive,
      deltaPieces: pieces,
      idempotencyKey: idempotencyKey,
      syncState: SyncState.pending,
      occurredAt: enqueuedAt,
    );
    await queue.enqueue(
      opType: OpType.receiveEntry,
      payload: '{"kind":"receive","pieces":$pieces}',
      idempotencyKey: idempotencyKey,
      enqueuedAt: enqueuedAt,
      executor: db,
    );
  });
}

/// A no-sleep [Clock] that records each requested backoff delay.
class _RecordingClock {
  final List<Duration> delays = <Duration>[];

  Future<void> call(Duration delay) async {
    delays.add(delay);
  }
}

/// How the controllable hosted wrapper should behave on an `apply` call.
enum _FaultMode {
  /// Delegate straight through to the real fake (apply exactly once).
  none,

  /// Apply the effect to the underlying store, then throw a transient error
  /// (simulates a lost/timed-out response for a request the server DID apply).
  lostResponse,

  /// Throw a transient error WITHOUT applying (simulates a dropped request).
  transientFail,

  /// Throw a definitive [HostedRejection] (permanent server rejection).
  reject,
}

/// A [HostedDatabase] wrapper that injects faults for the first N attempts and
/// otherwise delegates to a backing [FakeHostedDatabase].
class _FaultyHostedDatabase implements HostedDatabase {
  _FaultyHostedDatabase(this._inner, {required this.plan});

  final FakeHostedDatabase _inner;

  /// One entry per expected [apply] call: the fault to inject on that call.
  /// Calls beyond the plan length behave as [_FaultMode.none].
  final List<_FaultMode> plan;

  int applyCalls = 0;

  @override
  Future<HostedApplyResult> apply(HostedOperation operation) async {
    final mode = applyCalls < plan.length ? plan[applyCalls] : _FaultMode.none;
    applyCalls += 1;
    switch (mode) {
      case _FaultMode.none:
        return _inner.apply(operation);
      case _FaultMode.lostResponse:
        // The server applied it, but the client never learns the result.
        await _inner.apply(operation);
        throw TimeoutException('response lost after apply');
      case _FaultMode.transientFail:
        throw TimeoutException('request dropped before apply');
      case _FaultMode.reject:
        throw HostedRejection(operation.idempotencyKey, 'validation failed');
    }
  }

  @override
  Future<T> runTransaction<T>(
    FutureOr<T> Function(HostedTransaction txn) body,
  ) =>
      _inner.runTransaction<T>(body);

  @override
  Future<Map<String, Object?>> readConfirmed(String idempotencyKey) =>
      _inner.readConfirmed(idempotencyKey);
}

void main() {
  group('SyncService — ordered drain, idempotent apply, retry/backoff', () {
    late AppDatabase db;
    late FakeAuthService auth;
    late PendingOperationQueue queue;
    late StockLedgerDao ledger;
    late int stockItemId;

    setUp(() async {
      db = openInMemoryDatabase();
      auth = FakeAuthService(initialSession: const AuthSession(userId: 'o'));
      queue = PendingOperationQueue(db);
      ledger = StockLedgerDao(db);
      stockItemId = await _seedStockItem(db);
    });

    tearDown(() async {
      await auth.dispose();
      await db.close();
    });

    test('drains pending ops in enqueue order and flips pending -> confirmed',
        () async {
      await _enqueuePendingReceive(
        db,
        stockItemId: stockItemId,
        pieces: 10,
        idempotencyKey: 'op-a',
        enqueuedAt: DateTime.utc(2024, 1, 1, 9),
      );
      await _enqueuePendingReceive(
        db,
        stockItemId: stockItemId,
        pieces: 20,
        idempotencyKey: 'op-b',
        enqueuedAt: DateTime.utc(2024, 1, 1, 10),
      );

      // Before sync: both pending, nothing sellable.
      final before = await ledger.readStoredBalances(stockItemId);
      expect(before.confirmedPieces, 0);
      expect(before.pendingPieces, 30);

      final hosted = FakeHostedDatabase(authService: auth);
      final service = SyncService(
        hostedDatabase: hosted,
        pendingQueue: queue,
        stockLedger: ledger,
        authService: auth,
      );

      final result = await service.drain();

      // Drain order follows enqueue order.
      expect(
        result.results.map((r) => r.idempotencyKey).toList(),
        <String>['op-a', 'op-b'],
      );
      expect(result.confirmed.length, 2);
      expect(result.isFullyDrained, isTrue);

      // Each op applied exactly once in the hosted store.
      expect(hosted.appliedCount, 2);
      expect(hosted.hasApplied('op-a'), isTrue);
      expect(hosted.hasApplied('op-b'), isTrue);

      // Local movements promoted pending -> confirmed (now sellable).
      final after = await ledger.readStoredBalances(stockItemId);
      expect(after.confirmedPieces, 30);
      expect(after.pendingPieces, 0);

      // Queue rows are confirmed.
      final a = await queue.findByIdempotencyKey('op-a');
      final b = await queue.findByIdempotencyKey('op-b');
      expect(a!.syncState, SyncState.confirmed);
      expect(b!.syncState, SyncState.confirmed);
    });

    test('a lost response retried with the same key yields exactly one effect',
        () async {
      await _enqueuePendingReceive(
        db,
        stockItemId: stockItemId,
        pieces: 10,
        idempotencyKey: 'op-lost',
        enqueuedAt: DateTime.utc(2024, 1, 1, 9),
      );

      final clock = _RecordingClock();
      final hosted = _FaultyHostedDatabase(
        FakeHostedDatabase(authService: auth),
        // First attempt: server applies but response is lost. Second attempt:
        // the retry (same key) is a duplicate no-op in the hosted store.
        plan: <_FaultMode>[_FaultMode.lostResponse],
      );
      final service = SyncService(
        hostedDatabase: hosted,
        pendingQueue: queue,
        stockLedger: ledger,
        authService: auth,
        backoffStrategy: const ExponentialBackoff(maxAttempts: 5),
        sleepClock: clock.call,
      );

      final result = await service.drain();

      // Succeeded on the retry.
      final op = result.results.single;
      expect(op.status, SyncOpStatus.confirmed);
      expect(op.attempts, 2);
      expect(hosted.applyCalls, 2);

      // Exactly one hosted effect despite the retry (Requirement 19.10).
      expect(hosted._inner.appliedCount, 1);

      // Local movement promoted exactly once: no double-add.
      final after = await ledger.readStoredBalances(stockItemId);
      expect(after.confirmedPieces, 10);
      expect(after.pendingPieces, 0);

      // Backoff was applied once (between the two attempts), without sleeping.
      expect(clock.delays.length, 1);
    });

    test('a transient failure retries with backoff then succeeds', () async {
      await _enqueuePendingReceive(
        db,
        stockItemId: stockItemId,
        pieces: 10,
        idempotencyKey: 'op-flaky',
        enqueuedAt: DateTime.utc(2024, 1, 1, 9),
      );

      final clock = _RecordingClock();
      final hosted = _FaultyHostedDatabase(
        FakeHostedDatabase(authService: auth),
        // Two dropped requests, then success on the third attempt.
        plan: <_FaultMode>[
          _FaultMode.transientFail,
          _FaultMode.transientFail,
        ],
      );
      final service = SyncService(
        hostedDatabase: hosted,
        pendingQueue: queue,
        stockLedger: ledger,
        authService: auth,
        backoffStrategy: const ExponentialBackoff(
          base: Duration(milliseconds: 10),
          maxAttempts: 5,
        ),
        sleepClock: clock.call,
      );

      final result = await service.drain();

      final op = result.results.single;
      expect(op.status, SyncOpStatus.confirmed);
      expect(op.attempts, 3);
      expect(hosted.applyCalls, 3);
      expect(hosted._inner.appliedCount, 1);

      // Exponential backoff between attempts: 10ms then 20ms.
      expect(clock.delays, <Duration>[
        const Duration(milliseconds: 10),
        const Duration(milliseconds: 20),
      ]);

      final after = await ledger.readStoredBalances(stockItemId);
      expect(after.confirmedPieces, 10);
      expect(after.pendingPieces, 0);
    });

    test('a permanent rejection marks the op failed and does not confirm',
        () async {
      await _enqueuePendingReceive(
        db,
        stockItemId: stockItemId,
        pieces: 10,
        idempotencyKey: 'op-bad',
        enqueuedAt: DateTime.utc(2024, 1, 1, 9),
      );

      final clock = _RecordingClock();
      final hosted = _FaultyHostedDatabase(
        FakeHostedDatabase(authService: auth),
        plan: <_FaultMode>[_FaultMode.reject],
      );
      final service = SyncService(
        hostedDatabase: hosted,
        pendingQueue: queue,
        stockLedger: ledger,
        authService: auth,
        sleepClock: clock.call,
      );

      final result = await service.drain();

      final op = result.results.single;
      expect(op.status, SyncOpStatus.failed);
      expect(op.error, 'validation failed');
      // No retry on a definitive rejection, and no backoff.
      expect(op.attempts, 1);
      expect(clock.delays, isEmpty);

      // Not promoted: still pending in the ledger, nothing sellable.
      final after = await ledger.readStoredBalances(stockItemId);
      expect(after.confirmedPieces, 0);
      expect(after.pendingPieces, 10);

      // Queue row surfaces the failure with its last_error.
      final row = await queue.findByIdempotencyKey('op-bad');
      expect(row!.syncState, SyncState.failed);
      expect(row.lastError, 'validation failed');
    });

    test('draining without a session is refused and leaves ops pending',
        () async {
      await _enqueuePendingReceive(
        db,
        stockItemId: stockItemId,
        pieces: 10,
        idempotencyKey: 'op-nosession',
        enqueuedAt: DateTime.utc(2024, 1, 1, 9),
      );

      final signedOut = FakeAuthService();
      final hosted = FakeHostedDatabase(authService: signedOut);
      final service = SyncService(
        hostedDatabase: hosted,
        pendingQueue: queue,
        stockLedger: ledger,
        authService: signedOut,
      );

      await expectLater(
        service.drain(),
        throwsA(isA<NotAuthenticatedException>()),
      );

      // Nothing applied; the op is still pending and still not sellable.
      expect(hosted.appliedCount, 0);
      final row = await queue.findByIdempotencyKey('op-nosession');
      expect(row!.syncState, SyncState.pending);
      final after = await ledger.readStoredBalances(stockItemId);
      expect(after.confirmedPieces, 0);
      expect(after.pendingPieces, 10);

      await signedOut.dispose();
    });
  });
}
