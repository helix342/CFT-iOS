/// The hosted authoritative-database client abstraction (task 4.2).
///
/// [HostedDatabase] is the seam the sync engine (task 4.3, `SyncService`) and
/// the finalize/void flows (task 11.x) call to reach the **authoritative**
/// store (design.md -> Architecture: Hosted-DB access and credentials). It
/// defines three capabilities, kept deliberately minimal and
/// idempotency-key-centric:
///
///   * `apply` — apply a single operation idempotently (keyed by its
///     `idempotencyKey`); applying the same key again is a no-op that
///     re-returns the first outcome (Requirement 19.9, 19.10);
///   * `runTransaction` — run an authenticated, all-or-nothing transaction via
///     a callback (used by finalize/void: validate, allocate an invoice
///     number, deduct stock atomically — Requirement 12.2);
///   * `readConfirmed` — read confirmed authoritative state for a key, so the
///     local cache can reconcile pending -> confirmed.
///
/// Every privileged entry point requires an authenticated owner session: it
/// calls `AuthService.requireSession` and refuses with
/// `NotAuthenticatedException` when no one is signed in (Requirement 19.3).
///
/// ## Credentials never live in source
///
/// This interface — and the in-memory [FakeHostedDatabase] below — embed **no**
/// connection string, no anon key, and no service-role/privileged key. The real
/// implementation (wired later) follows the design's credential rule:
///
///   * **Supabase (preferred):** the app ships only the **client-safe anon
///     key**; privileged access is gated by Row Level Security keyed to the
///     authenticated owner session (Requirement 19.4). The anon key is supplied
///     from the environment at runtime, never checked into this repository.
///   * **Neon (alternative):** the app never holds a direct Postgres connection
///     string; it reaches Neon only through an **authenticated API** that holds
///     credentials server-side (Requirement 19.5).
///   * **Either way:** no privileged or service-role credential is embedded in
///     the app, source, GitHub, or CI secrets (Requirement 19.6, 20.7).
///
/// Architecture rule (design.md): this file is pure Dart. It MUST NOT import
/// `package:flutter/*` or `dart:io`, so it runs headless under `flutter test`
/// on Windows and lets `SyncService` + finalize be built and tested with no
/// network. Riverpod wiring lives in `hosted_database_providers.dart`.
library;

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:wood_cft/application/auth_service.dart';

/// A single idempotent operation submitted to the [HostedDatabase].
///
/// Mirrors a drained `PendingOperation` row: a kind, an opaque [payload]
/// (serialized by the caller), and the stable [idempotencyKey] that guarantees
/// the hosted effect is applied exactly once across retries and duplicates
/// (Requirement 19.9, 19.10).
@immutable
class HostedOperation {
  /// Creates an operation of [kind] carrying [payload], keyed by
  /// [idempotencyKey].
  const HostedOperation({
    required this.kind,
    required this.idempotencyKey,
    this.payload = const <String, Object?>{},
  });

  /// Caller-defined operation kind (e.g. `'receiveEntry'`, `'finalize'`). The
  /// hosted store does not interpret it beyond recording it on the result.
  final String kind;

  /// The stable idempotency key. Re-applying the same key is a no-op that
  /// returns the original [HostedApplyResult].
  final String idempotencyKey;

  /// Opaque payload for the operation. Treated as an immutable snapshot.
  final Map<String, Object?> payload;

  @override
  String toString() =>
      'HostedOperation(kind: $kind, idempotencyKey: $idempotencyKey)';
}

/// The outcome of applying a [HostedOperation] to the [HostedDatabase].
///
/// [applied] is `true` when this call produced the effect, and `false` when the
/// [idempotencyKey] had already been applied (the duplicate path). Either way
/// the hosted effect exists exactly once (Requirement 19.9). [confirmedState]
/// is the authoritative state the hosted store recorded under this key.
@immutable
class HostedApplyResult {
  /// Creates a result for [idempotencyKey]; [applied] distinguishes the
  /// first application from a duplicate replay.
  const HostedApplyResult({
    required this.idempotencyKey,
    required this.applied,
    this.confirmedState = const <String, Object?>{},
  });

  /// The idempotency key this result is for.
  final String idempotencyKey;

  /// `true` if this call applied the effect; `false` if it was a duplicate of
  /// an already-applied key (the effect was not applied a second time).
  final bool applied;

  /// The authoritative confirmed state recorded under [idempotencyKey].
  final Map<String, Object?> confirmedState;

  @override
  String toString() => 'HostedApplyResult(idempotencyKey: $idempotencyKey, '
      'applied: $applied)';
}

/// A privileged, authenticated handle passed to a [HostedDatabase.runTransaction]
/// callback.
///
/// Inside the callback the caller performs the staged writes that must commit
/// together (finalize: validate, allocate invoice number, deduct stock). If the
/// callback throws, the transaction rolls back and none of the staged writes
/// take effect (Requirement 12.4). The handle exposes the authenticated
/// [session] so callers can key RLS-scoped writes.
abstract interface class HostedTransaction {
  /// The authenticated owner session this transaction runs under.
  AuthSession get session;

  /// Stages a [HostedOperation] inside the transaction. Applied idempotently on
  /// commit; staging the same [HostedOperation.idempotencyKey] twice within the
  /// transaction collapses to a single effect.
  void stage(HostedOperation operation);
}

/// Thrown by [HostedDatabase.readConfirmed] when a key has no confirmed state.
class HostedStateNotFoundException implements Exception {
  /// Creates the exception for the missing [idempotencyKey].
  const HostedStateNotFoundException(this.idempotencyKey);

  /// The key that has no confirmed state in the hosted store.
  final String idempotencyKey;

  @override
  String toString() =>
      'HostedStateNotFoundException: no confirmed state for '
      '"$idempotencyKey"';
}

/// The authoritative hosted-database client.
///
/// All three methods are privileged and require an authenticated owner session
/// (Requirement 19.3). Implementations MUST apply operations idempotently under
/// their idempotency key and MUST make [runTransaction] all-or-nothing.
abstract interface class HostedDatabase {
  /// Applies [operation] idempotently to the authoritative store.
  ///
  /// Requires an authenticated session (throws [NotAuthenticatedException]
  /// otherwise). The first call for a given [HostedOperation.idempotencyKey]
  /// applies the effect and returns a result with `applied == true`; any later
  /// call with the same key is a no-op that returns the original outcome with
  /// `applied == false` (Requirement 19.9, 19.10).
  Future<HostedApplyResult> apply(HostedOperation operation);

  /// Runs [body] inside a single authenticated, all-or-nothing transaction and
  /// returns its value.
  ///
  /// Requires an authenticated session (throws [NotAuthenticatedException]
  /// otherwise). Operations staged via [HostedTransaction.stage] commit
  /// together on success; if [body] throws, every staged write is rolled back
  /// and the hosted state is left exactly as before (Requirement 12.2, 12.4).
  Future<T> runTransaction<T>(
    FutureOr<T> Function(HostedTransaction txn) body,
  );

  /// Reads the confirmed authoritative state recorded under [idempotencyKey].
  ///
  /// Requires an authenticated session. Throws [HostedStateNotFoundException]
  /// when the key has not been applied, so the local cache can tell "not yet
  /// confirmed" from "confirmed with empty state".
  Future<Map<String, Object?>> readConfirmed(String idempotencyKey);
}

/// In-memory [HostedDatabase] for tests and for the app until a real
/// Supabase/Neon-backed client is wired (task 4.2).
///
/// Simulates the authoritative store with a map keyed by idempotency key, and
/// **embeds no credentials**. It integrates [AuthService]: every privileged
/// call goes through [AuthService.requireSession], so a privileged apply or
/// transaction with no session throws [NotAuthenticatedException]. Applications
/// are idempotent (same key -> applied exactly once) and transactions are
/// all-or-nothing (a throwing body leaves no partial effect). Safe to construct
/// in a `flutter test` on Windows with no network.
class FakeHostedDatabase implements HostedDatabase {
  /// Creates the fake, gating privileged access with [authService].
  FakeHostedDatabase({required AuthService authService})
    : _auth = authService;

  final AuthService _auth;

  /// Committed authoritative state, keyed by idempotency key. Presence of a key
  /// means its effect has been applied exactly once.
  final Map<String, Map<String, Object?>> _applied =
      <String, Map<String, Object?>>{};

  @override
  Future<HostedApplyResult> apply(HostedOperation operation) async {
    _auth.requireSession('hosted apply (${operation.kind})');
    return _applyInternal(operation);
  }

  /// Shared apply path used by [apply] and transaction commit. Assumes the
  /// session has already been checked by the caller.
  HostedApplyResult _applyInternal(HostedOperation operation) {
    final key = operation.idempotencyKey;
    final existing = _applied[key];
    if (existing != null) {
      // Duplicate key: the effect already exists; do not apply it again.
      return HostedApplyResult(
        idempotencyKey: key,
        applied: false,
        confirmedState: existing,
      );
    }
    final state = Map<String, Object?>.unmodifiable(operation.payload);
    _applied[key] = state;
    return HostedApplyResult(
      idempotencyKey: key,
      applied: true,
      confirmedState: state,
    );
  }

  @override
  Future<T> runTransaction<T>(
    FutureOr<T> Function(HostedTransaction txn) body,
  ) async {
    final session = _auth.requireSession('hosted transaction');
    final txn = _FakeHostedTransaction(session);

    final T result;
    try {
      result = await body(txn);
    } on Object {
      // The body threw: discard every staged op. Nothing is committed, so the
      // authoritative state is unchanged (all-or-nothing rollback).
      rethrow;
    }

    // The body completed: commit all staged ops idempotently, in stage order.
    for (final op in txn.staged) {
      _applyInternal(op);
    }
    return result;
  }

  @override
  Future<Map<String, Object?>> readConfirmed(String idempotencyKey) async {
    _auth.requireSession('hosted read');
    final state = _applied[idempotencyKey];
    if (state == null) {
      throw HostedStateNotFoundException(idempotencyKey);
    }
    return state;
  }

  /// Visible-for-testing: whether [idempotencyKey] has a committed effect.
  @visibleForTesting
  bool hasApplied(String idempotencyKey) => _applied.containsKey(idempotencyKey);

  /// Visible-for-testing: the number of distinct applied operations.
  @visibleForTesting
  int get appliedCount => _applied.length;
}

/// In-memory [HostedTransaction] that buffers staged ops until commit.
///
/// Staging only records intent; nothing touches the authoritative store until
/// [FakeHostedDatabase.runTransaction] commits after the body returns. A body
/// that throws means these staged ops are discarded, so there is no partial
/// effect. Duplicate idempotency keys staged within one transaction collapse to
/// a single effect (the first wins; later stages of the same key are ignored).
class _FakeHostedTransaction implements HostedTransaction {
  _FakeHostedTransaction(this.session);

  @override
  final AuthSession session;

  final List<HostedOperation> _staged = <HostedOperation>[];
  final Set<String> _stagedKeys = <String>{};

  /// The staged ops, in stage order, with duplicate keys removed.
  List<HostedOperation> get staged => List<HostedOperation>.unmodifiable(_staged);

  @override
  void stage(HostedOperation operation) {
    if (_stagedKeys.add(operation.idempotencyKey)) {
      _staged.add(operation);
    }
  }
}
