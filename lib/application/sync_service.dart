/// The sync engine that drains the pending-op queue to the hosted database
/// (task 4.3).
///
/// [SyncService] implements design.md -> Transaction Boundaries & Sync (Sync
/// engine). It drains the durable [PendingOperationQueue] **in enqueue order**
/// and applies each operation to the authoritative [HostedDatabase] using the
/// op's stable idempotency key, so a retried or duplicated operation is applied
/// **exactly once** in the hosted DB (Requirement 19.9). On a successful
/// confirmation it flips the queue row to `Confirmed` and promotes the local
/// movement from `pending_balance_pieces` to `confirmed_balance_pieces` so the
/// stock becomes sellable (Requirement 19.8).
///
/// ## Transient vs permanent outcomes
///
/// Each apply has one of three outcomes:
///
///   * **Success** — the hosted DB acknowledged the apply. The queue row is
///     marked `Confirmed` ([PendingOperationQueue.markConfirmed]) and the local
///     movement is confirmed ([StockLedgerDao.confirmMovement]).
///   * **Uncertain / transient** — a lost response, timeout, or any error that
///     is *not* a definitive server rejection. The outcome is unknown, so the
///     op MUST be retried **with the same idempotency key**; a lost response
///     that is retried can never create a duplicate movement because the hosted
///     DB applies the key exactly once (Requirement 19.10, 21.26). Retries use
///     **exponential backoff** between attempts. Transient errors are modelled
///     as any thrown object that is not a [HostedRejection].
///   * **Permanent rejection** — the server definitively rejected the op (bad
///     payload, violated invariant). This is modelled as a [HostedRejection].
///     The op is marked `Failed` with `last_error`
///     ([PendingOperationQueue.markFailed]) and is **never promoted** to
///     confirmed; it is surfaced to the owner. The drain continues with the
///     next op.
///
/// Because a lost-but-actually-applied response is indistinguishable from a
/// genuine transient failure, both are retried with the same key and the hosted
/// DB's idempotency guarantees exactly-once (Requirement 19.10).
///
/// ## Authenticated session required
///
/// Draining is a privileged hosted action: `drain` calls
/// `AuthService.requireSession` first and refuses when no owner is signed in,
/// leaving every op pending so nothing is lost (Requirement 19.3). The hosted
/// DB independently gates each call too.
///
/// ## Headless and deterministic
///
/// The [HostedDatabase], [PendingOperationQueue], [StockLedgerDao],
/// [AuthService], the [BackoffStrategy], and the sleep [Clock] are all injected,
/// so the service is pure application logic with no Flutter/IO dependency and
/// runs under `flutter test` on Windows. Tests inject a fake clock so backoff
/// never really sleeps.
library;

import 'dart:async';

import 'package:meta/meta.dart';

import 'package:wood_cft/application/auth_service.dart';
import 'package:wood_cft/data/app_database.dart' show PendingOperationRow;
import 'package:wood_cft/data/hosted_database.dart';
import 'package:wood_cft/data/pending_operation_queue.dart';
import 'package:wood_cft/data/stock_ledger_dao.dart';

/// Thrown by a [HostedDatabase] to signal a **definitive server rejection** of
/// an operation (a permanent failure), as opposed to an uncertain/transient
/// outcome.
///
/// A [SyncService] treats a [HostedRejection] as permanent: it marks the queue
/// row `Failed` with [message] and never retries or promotes it. Any other
/// thrown object is treated as transient (uncertain) and retried with the same
/// idempotency key under exponential backoff (Requirement 19.10).
class HostedRejection implements Exception {
  /// Creates a rejection for [idempotencyKey] with a human-readable [message].
  const HostedRejection(this.idempotencyKey, this.message);

  /// The idempotency key of the operation the server rejected.
  final String idempotencyKey;

  /// Human-readable reason recorded in the queue row's `last_error`.
  final String message;

  @override
  String toString() => 'HostedRejection($idempotencyKey): $message';
}

/// A function that waits for [delay] before completing. Injected so tests can
/// supply a fake clock that completes instantly (no real sleeping).
typedef Clock = Future<void> Function(Duration delay);

/// The default [Clock]: a real `Future.delayed`. Never used in tests.
Future<void> realClock(Duration delay) => Future<void>.delayed(delay);

/// Computes the backoff delay before a retry, given the number of attempts
/// already made (1 = after the first failed attempt).
///
/// Injected so the retry policy is configurable and tests stay deterministic.
abstract interface class BackoffStrategy {
  /// The delay to wait before the next attempt, given [attempt] attempts have
  /// already failed (`attempt >= 1`).
  Duration delayForAttempt(int attempt);

  /// The maximum number of attempts for a single operation before it is left
  /// pending (retried on a later drain). Must be `>= 1`.
  int get maxAttempts;
}

/// Exponential backoff: `base * 2^(attempt-1)`, capped at [maxDelay].
@immutable
class ExponentialBackoff implements BackoffStrategy {
  /// Creates an exponential backoff policy.
  const ExponentialBackoff({
    this.base = const Duration(milliseconds: 200),
    this.maxDelay = const Duration(seconds: 30),
    this.maxAttempts = 5,
  }) : assert(maxAttempts >= 1, 'maxAttempts must be >= 1');

  /// The delay before the first retry; each subsequent retry doubles it.
  final Duration base;

  /// Upper bound on any single backoff delay.
  final Duration maxDelay;

  @override
  final int maxAttempts;

  @override
  Duration delayForAttempt(int attempt) {
    final clamped = attempt < 1 ? 1 : attempt;
    // Shift the base by (attempt-1) bits == multiply by 2^(attempt-1), but
    // guard against overflow for large attempt counts by capping early.
    final shift = clamped - 1;
    if (shift >= 32) return maxDelay;
    final micros = base.inMicroseconds * (1 << shift);
    final delay = Duration(microseconds: micros);
    return delay > maxDelay ? maxDelay : delay;
  }
}

/// Why a single operation's processing ended.
enum SyncOpStatus {
  /// The hosted DB acknowledged the apply; the op is now confirmed and the
  /// local movement was promoted pending -> confirmed.
  confirmed,

  /// The server definitively rejected the op; it was marked `Failed` and never
  /// promoted.
  failed,

  /// Every attempt had an uncertain/transient outcome; the op is left pending
  /// to be retried on a later drain.
  stillPending,
}

/// The result of processing one queued operation.
@immutable
class SyncOpResult {
  /// Creates a per-op result.
  const SyncOpResult({
    required this.idempotencyKey,
    required this.status,
    required this.attempts,
    this.error,
  });

  /// The idempotency key of the processed op.
  final String idempotencyKey;

  /// How processing of this op ended.
  final SyncOpStatus status;

  /// The number of hosted apply attempts made for this op during this drain.
  final int attempts;

  /// The error recorded when [status] is [SyncOpStatus.failed] or the last
  /// transient error when [status] is [SyncOpStatus.stillPending].
  final String? error;

  @override
  String toString() =>
      'SyncOpResult($idempotencyKey, $status, attempts: $attempts)';
}

/// The aggregate result of a drain pass.
@immutable
class SyncResult {
  /// Creates a drain result from the per-op [results].
  const SyncResult(this.results);

  /// One entry per op the drain processed, in drain (enqueue) order.
  final List<SyncOpResult> results;

  /// The ops confirmed in this drain.
  Iterable<SyncOpResult> get confirmed =>
      results.where((r) => r.status == SyncOpStatus.confirmed);

  /// The ops the server rejected in this drain (surfaced to the owner).
  Iterable<SyncOpResult> get failed =>
      results.where((r) => r.status == SyncOpStatus.failed);

  /// The ops left pending (exhausted retries without a definitive outcome).
  Iterable<SyncOpResult> get stillPending =>
      results.where((r) => r.status == SyncOpStatus.stillPending);

  /// Whether every processed op reached a terminal state (confirmed or failed).
  bool get isFullyDrained => stillPending.isEmpty;

  @override
  String toString() =>
      'SyncResult(confirmed: ${confirmed.length}, failed: ${failed.length}, '
      'stillPending: ${stillPending.length})';
}

/// Drains the pending-op queue to the hosted database with idempotent apply and
/// exponential-backoff retry.
class SyncService {
  /// Creates a sync service wiring the injected collaborators.
  ///
  /// [backoffStrategy] defaults to a standard [ExponentialBackoff];
  /// [sleepClock] defaults to [realClock]. Tests inject a fake clock so backoff
  /// never really sleeps.
  SyncService({
    required HostedDatabase hostedDatabase,
    required PendingOperationQueue pendingQueue,
    required StockLedgerDao stockLedger,
    required AuthService authService,
    BackoffStrategy backoffStrategy = const ExponentialBackoff(),
    Clock sleepClock = realClock,
  })  : _hosted = hostedDatabase,
        _queue = pendingQueue,
        _ledger = stockLedger,
        _auth = authService,
        _backoff = backoffStrategy,
        _clock = sleepClock;

  final HostedDatabase _hosted;
  final PendingOperationQueue _queue;
  final StockLedgerDao _ledger;
  final AuthService _auth;
  final BackoffStrategy _backoff;
  final Clock _clock;

  /// Drains the pending-op queue in enqueue order, applying each op to the
  /// hosted database exactly once under its idempotency key.
  ///
  /// Requires an authenticated owner session: throws
  /// [NotAuthenticatedException] (via [AuthService.requireSession]) when no one
  /// is signed in, leaving every op pending (Requirement 19.3). On success each
  /// op is confirmed and its local movement promoted pending -> confirmed; a
  /// definitive [HostedRejection] marks the op `Failed`; an uncertain outcome
  /// is retried with the same key under exponential backoff and, if attempts
  /// are exhausted, the op is left pending for a later drain (Requirement 19.8,
  /// 19.9, 19.10).
  Future<SyncResult> drain() async {
    // Privileged action: refuse (and leave everything pending) with no session.
    _auth.requireSession('sync drain');

    final pending = await _queue.readPendingInOrder();
    final results = <SyncOpResult>[];
    for (final row in pending) {
      results.add(await _processOne(row));
    }
    return SyncResult(results);
  }

  /// Processes a single queued op with retry/backoff and returns its result.
  Future<SyncOpResult> _processOne(PendingOperationRow row) async {
    final operation = HostedOperation(
      kind: row.opType.name,
      idempotencyKey: row.idempotencyKey,
      payload: <String, Object?>{
        'opType': row.opType.name,
        'payload': row.payload,
      },
    );

    String? lastTransientError;
    var attempts = 0;

    while (attempts < _backoff.maxAttempts) {
      // Count the attempt both locally and durably so backoff/metrics survive a
      // restart mid-drain.
      attempts += 1;
      await _queue.incrementAttempts(row.id);

      try {
        await _hosted.apply(operation);
      } on HostedRejection catch (rejection) {
        // Definitive server rejection: mark failed, never promote, surface it.
        await _queue.markFailed(row.id, rejection.message);
        return SyncOpResult(
          idempotencyKey: row.idempotencyKey,
          status: SyncOpStatus.failed,
          attempts: attempts,
          error: rejection.message,
        );
      } on Object catch (error) {
        // Uncertain/transient outcome (lost response, timeout, network error):
        // retry with the SAME idempotency key. The hosted DB applies the key
        // exactly once, so a lost-but-applied response cannot duplicate the
        // movement (Requirement 19.10, 21.26).
        lastTransientError = error.toString();
        if (attempts >= _backoff.maxAttempts) break;
        await _clock(_backoff.delayForAttempt(attempts));
        continue;
      }

      // Success: confirm the queue row and promote the local movement from the
      // pending balance to the confirmed (sellable) balance (Requirement 19.8).
      await _queue.markConfirmed(row.id);
      await _ledger.confirmMovement(row.idempotencyKey);
      return SyncOpResult(
        idempotencyKey: row.idempotencyKey,
        status: SyncOpStatus.confirmed,
        attempts: attempts,
      );
    }

    // Exhausted retries without a definitive outcome: leave the op pending so a
    // later drain retries it (still with the same key). Not promoted, not
    // failed.
    return SyncOpResult(
      idempotencyKey: row.idempotencyKey,
      status: SyncOpStatus.stillPending,
      attempts: attempts,
      error: lastTransientError,
    );
  }
}
