/// Supabase-backed [HostedDatabase] (supabase-integration spec, Task 4).
///
/// Implements the authoritative store behind the existing [HostedDatabase]
/// interface, keeping its signatures unchanged (Requirement 3.1, 3.6):
///
///   * [SupabaseHostedDatabase.apply] upserts into the `applied_operations`
///     idempotency ledger keyed by `idempotency_key`. The first apply for a key
///     records its effect and returns `applied == true`; a duplicate key is a
///     no-op that returns the stored `confirmed_state` with `applied == false`
///     (Requirement 3.3), matching the fake's contract.
///   * [SupabaseHostedDatabase.runTransaction] runs atomic flows (finalize,
///     void) as Postgres RPC functions (`finalize_sale`, `void_invoice`)
///     invoked via the client; a throwing callback / failed RPC commits
///     nothing (Requirement 3.4).
///   * [SupabaseHostedDatabase.readConfirmed] selects the state recorded under a
///     key, throwing [HostedStateNotFoundException] when absent, consistent with
///     the fake (Requirement 3.5).
///
/// Every method is session-gated through [AuthService.requireSession]
/// (Requirement 3.2). PostgREST / auth errors are translated to the interface's
/// exceptions.
///
/// ## Headless-testability and credential hygiene
///
/// This file depends on narrow ports ([SupabasePostgrestPort],
/// [SupabaseRpcPort]) rather than importing the Supabase SDK into the type
/// surface used by callers, so mapping/idempotency tests inject in-memory stubs
/// with no network (Requirement 7.4). The SDK is referenced only inside the
/// adapters and [initializeSupabase], which read the project URL and anon key
/// from `--dart-define` via [String.fromEnvironment] with no hardcoded value
/// committed to source (Requirement 1.3, 1.5, 8.2).
library;

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wood_cft/application/auth_service.dart';
import 'package:wood_cft/application/supabase_auth_service.dart';
import 'package:wood_cft/data/hosted_database.dart';

/// `--dart-define` key for the Supabase project URL.
const String kSupabaseUrlEnv = 'SUPABASE_URL';

/// `--dart-define` key for the client-safe Supabase anon/publishable key.
const String kSupabaseAnonKeyEnv = 'SUPABASE_ANON_KEY';

/// PostgreSQL unique-violation SQLSTATE. A conflict on the idempotency key is
/// treated as a successful duplicate replay rather than an error.
const String kUniqueViolationCode = '23505';

/// A minimal, headless-testable view of PostgREST table operations used by
/// [SupabaseHostedDatabase].
///
/// The real adapter forwards to `SupabaseClient.from(...)`; tests inject an
/// in-memory stub. All methods operate under the authenticated owner (RLS adds
/// the `owner_id = auth.uid()` scope server-side).
abstract interface class SupabasePostgrestPort {
  /// Inserts a row into [table], failing with a unique-violation
  /// [PostgrestException] (`code == '23505'`) when the row's unique key already
  /// exists. Returns the inserted row.
  Future<Map<String, Object?>> insert(
    String table,
    Map<String, Object?> values,
  );

  /// Selects a single row from [table] whose [column] equals [value], or
  /// `null` when there is no match.
  Future<Map<String, Object?>?> selectOne(
    String table,
    String column,
    Object? value,
  );
}

/// A minimal, headless-testable view of Postgres RPC invocation.
///
/// The real adapter forwards to `SupabaseClient.rpc(...)`; tests inject a stub.
abstract interface class SupabaseRpcPort {
  /// Invokes the Postgres function [fn] with [params] and returns its result.
  Future<Object?> call(String fn, Map<String, Object?> params);
}

/// [HostedDatabase] backed by Supabase.
class SupabaseHostedDatabase implements HostedDatabase {
  /// Creates the database over the [postgrest] and [rpc] ports, gating every
  /// method with [authService].
  SupabaseHostedDatabase({
    required AuthService authService,
    required SupabasePostgrestPort postgrest,
    required SupabaseRpcPort rpc,
  })  : _auth = authService,
        // ignore: prefer_initializing_formals
        _postgrest = postgrest,
        // ignore: prefer_initializing_formals
        _rpc = rpc;

  /// The idempotency ledger table backing [apply] / [readConfirmed].
  static const String appliedOperationsTable = 'applied_operations';

  final AuthService _auth;
  final SupabasePostgrestPort _postgrest;
  final SupabaseRpcPort _rpc;

  @override
  Future<HostedApplyResult> apply(HostedOperation operation) async {
    _auth.requireSession('hosted apply (${operation.kind})');
    final key = operation.idempotencyKey;

    try {
      final row = await _postgrest.insert(appliedOperationsTable, {
        'idempotency_key': key,
        'kind': operation.kind,
        'confirmed_state': operation.payload,
      });
      return HostedApplyResult(
        idempotencyKey: key,
        applied: true,
        confirmedState: _readConfirmedState(row),
      );
    } on PostgrestException catch (error) {
      if (_isUniqueViolation(error)) {
        // Duplicate key: the effect already exists. Re-read and return the
        // stored state with applied == false (Requirement 3.3).
        final existing = await _postgrest.selectOne(
          appliedOperationsTable,
          'idempotency_key',
          key,
        );
        return HostedApplyResult(
          idempotencyKey: key,
          applied: false,
          confirmedState:
              existing == null ? const {} : _readConfirmedState(existing),
        );
      }
      throw _translate(error);
    }
  }

  @override
  Future<T> runTransaction<T>(
    FutureOr<T> Function(HostedTransaction txn) body,
  ) async {
    final session = _auth.requireSession('hosted transaction');
    final txn = _SupabaseHostedTransaction(session);

    final T result;
    try {
      result = await body(txn);
    } on Object {
      // The body threw before staging completed: nothing was sent to the
      // server, so there is no partial effect (Requirement 3.4).
      rethrow;
    }

    // Apply staged ops through their RPC functions. Each RPC is atomic
    // server-side and idempotent on its key; a failed RPC commits nothing.
    for (final op in txn.staged) {
      try {
        await _rpc.call(_rpcFor(op.kind), {
          'p_idempotency_key': op.idempotencyKey,
          ...op.payload,
        });
      } on PostgrestException catch (error) {
        throw _translate(error);
      }
    }
    return result;
  }

  @override
  Future<Map<String, Object?>> readConfirmed(String idempotencyKey) async {
    _auth.requireSession('hosted read');
    final Map<String, Object?>? row;
    try {
      row = await _postgrest.selectOne(
        appliedOperationsTable,
        'idempotency_key',
        idempotencyKey,
      );
    } on PostgrestException catch (error) {
      throw _translate(error);
    }
    if (row == null) {
      throw HostedStateNotFoundException(idempotencyKey);
    }
    return _readConfirmedState(row);
  }

  /// Maps an operation kind to its Postgres RPC function name.
  String _rpcFor(String kind) {
    switch (kind) {
      case 'finalize':
        return 'finalize_sale';
      case 'void':
        return 'void_invoice';
      default:
        return kind;
    }
  }

  /// Extracts the `confirmed_state` map from an `applied_operations` row,
  /// tolerating a missing/typed-wrong column by returning an empty map.
  Map<String, Object?> _readConfirmedState(Map<String, Object?> row) {
    final state = row['confirmed_state'];
    if (state is Map) {
      return Map<String, Object?>.unmodifiable(
        state.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return const <String, Object?>{};
  }

  bool _isUniqueViolation(PostgrestException error) =>
      error.code == kUniqueViolationCode;

  /// Translates a [PostgrestException] to an interface exception where one
  /// applies. Auth failures (RLS / missing session, SQLSTATE `28000`) map to
  /// [NotAuthenticatedException]; everything else is surfaced unchanged so a
  /// retry can reuse the same idempotency key (exactly-once preserved).
  Object _translate(PostgrestException error) {
    final code = error.code;
    if (code == '28000' || code == '42501') {
      return const NotAuthenticatedException('hosted database');
    }
    return error;
  }
}

/// [HostedTransaction] that buffers staged ops until the body returns, so a
/// throwing body stages nothing and no RPC runs (all-or-nothing).
class _SupabaseHostedTransaction implements HostedTransaction {
  _SupabaseHostedTransaction(this.session);

  @override
  final AuthSession session;

  final List<HostedOperation> _staged = <HostedOperation>[];
  final Set<String> _stagedKeys = <String>{};

  /// The staged ops, in stage order, with duplicate keys removed.
  List<HostedOperation> get staged =>
      List<HostedOperation>.unmodifiable(_staged);

  @override
  void stage(HostedOperation operation) {
    if (_stagedKeys.add(operation.idempotencyKey)) {
      _staged.add(operation);
    }
  }
}

// ---------------------------------------------------------------------------
// Bootstrap helper + real SDK adapters
//
// These are the only places that touch the Supabase SDK. `main.dart` (wired by
// the orchestrator) calls [initializeSupabase] once at startup, then builds the
// adapters below.
// ---------------------------------------------------------------------------

/// Thrown by [initializeSupabase] when the required `--dart-define`
/// configuration is missing, so the app fails fast rather than connecting with
/// blank credentials (Requirement 1.4).
class SupabaseConfigException implements Exception {
  /// Creates the exception naming the missing [variable].
  const SupabaseConfigException(this.variable);

  /// The `--dart-define` key that was absent or empty.
  final String variable;

  @override
  String toString() => 'SupabaseConfigException: missing required '
      '--dart-define $variable';
}

/// Initializes the Supabase client exactly once from `--dart-define`
/// configuration (Requirement 1.2, 1.3, 1.4).
///
/// Reads [kSupabaseUrlEnv] and [kSupabaseAnonKeyEnv] via
/// [String.fromEnvironment] — there is no hardcoded fallback, so no secret
/// lives in source (Requirement 1.5, 8.2). Throws [SupabaseConfigException]
/// when either value is absent. `main.dart` (orchestrator-owned) awaits this
/// before any hosted access.
Future<void> initializeSupabase() async {
  const url = String.fromEnvironment(kSupabaseUrlEnv);
  const anonKey = String.fromEnvironment(kSupabaseAnonKeyEnv);
  if (url.isEmpty) {
    throw const SupabaseConfigException(kSupabaseUrlEnv);
  }
  if (anonKey.isEmpty) {
    throw const SupabaseConfigException(kSupabaseAnonKeyEnv);
  }
  await Supabase.initialize(url: url, publishableKey: anonKey);
}

/// Adapts the live `GoTrueClient` to [SupabaseAuthPort].
class SupabaseGoTrueAuthPort implements SupabaseAuthPort {
  /// Creates the adapter over [auth] (default: the initialized client's auth).
  SupabaseGoTrueAuthPort({GoTrueClient? auth})
      : _auth = auth ?? Supabase.instance.client.auth;

  final GoTrueClient _auth;

  @override
  String? get currentUserId => _auth.currentUser?.id;

  @override
  Stream<String?> get userIdChanges =>
      _auth.onAuthStateChange.map((state) => state.session?.user.id);

  @override
  Future<String> signInAnonymously() async {
    final response = await _auth.signInAnonymously();
    final user = response.user ?? _auth.currentUser;
    if (user == null) {
      throw const NotAuthenticatedException('anonymous sign-in');
    }
    return user.id;
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

/// Adapts the live `SupabaseClient` to [SupabasePostgrestPort].
class SupabaseClientPostgrestPort implements SupabasePostgrestPort {
  /// Creates the adapter over [client] (default: the initialized client).
  SupabaseClientPostgrestPort({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<Map<String, Object?>> insert(
    String table,
    Map<String, Object?> values,
  ) async {
    final row =
        await _client.from(table).insert(values).select().single();
    return Map<String, Object?>.from(row);
  }

  @override
  Future<Map<String, Object?>?> selectOne(
    String table,
    String column,
    Object? value,
  ) async {
    final row = await _client
        .from(table)
        .select()
        .eq(column, value as Object)
        .maybeSingle();
    return row == null ? null : Map<String, Object?>.from(row);
  }
}

/// Adapts the live `SupabaseClient` RPC entry point to [SupabaseRpcPort].
class SupabaseClientRpcPort implements SupabaseRpcPort {
  /// Creates the adapter over [client] (default: the initialized client).
  SupabaseClientRpcPort({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<Object?> call(String fn, Map<String, Object?> params) =>
      _client.rpc<Object?>(fn, params: params);
}
