// Mapping + idempotency unit tests for SupabaseHostedDatabase
// (supabase-integration spec, Task 6).
//
// Runs against in-memory SupabasePostgrestPort / SupabaseRpcPort stubs — no
// network, no live Supabase client. Validates:
//   * apply records an effect once and returns applied == true (Req 3.1);
//   * a unique-violation on the idempotency key is a successful duplicate
//     replay: applied == false, stored confirmed_state returned (Req 3.3 /
//     Property 32), matching the fake's contract;
//   * every method is session-gated -> NotAuthenticatedException (Req 3.2);
//   * readConfirmed signals not-found consistently with the fake (Req 3.5);
//   * PostgREST auth errors (28000 / 42501) map to NotAuthenticatedException;
//   * runTransaction routes staged ops to the finalize_sale / void_invoice
//     RPCs and a throwing body stages nothing (all-or-nothing, Req 3.4).
//
// Constructing a PostgrestException value is a pure data object (no network);
// it is the error type the real adapter would surface, so the mapping is
// exercised without a client.

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:wood_cft/application/auth_service.dart';
import 'package:wood_cft/data/hosted_database.dart';
import 'package:wood_cft/data/supabase_hosted_database.dart';

/// In-memory PostgREST stub modeling the unique-constraint on idempotency_key.
class _StubPostgrest implements SupabasePostgrestPort {
  final Map<String, Map<String, Object?>> _rows = <String, Map<String, Object?>>{};

  /// Optional error to throw on the next insert (for error-mapping tests).
  PostgrestException? insertError;

  @override
  Future<Map<String, Object?>> insert(
    String table,
    Map<String, Object?> values,
  ) async {
    final error = insertError;
    if (error != null) {
      insertError = null;
      throw error;
    }
    final key = values['idempotency_key']! as String;
    if (_rows.containsKey(key)) {
      throw const PostgrestException(
        message: 'duplicate key value violates unique constraint',
        code: '23505',
      );
    }
    final row = Map<String, Object?>.from(values);
    _rows[key] = row;
    return row;
  }

  @override
  Future<Map<String, Object?>?> selectOne(
    String table,
    String column,
    Object? value,
  ) async {
    for (final row in _rows.values) {
      if (row[column] == value) return row;
    }
    return null;
  }
}

/// In-memory RPC stub recording calls.
class _StubRpc implements SupabaseRpcPort {
  final List<({String fn, Map<String, Object?> params})> calls =
      <({String fn, Map<String, Object?> params})>[];

  @override
  Future<Object?> call(String fn, Map<String, Object?> params) async {
    calls.add((fn: fn, params: params));
    return <String, Object?>{'status': 'ok'};
  }
}

SupabaseHostedDatabase _build(
  _StubPostgrest postgrest,
  _StubRpc rpc, {
  bool signedIn = true,
}) {
  final auth = FakeAuthService(
    initialSession:
        signedIn ? const AuthSession(userId: 'anon-1') : null,
  );
  addTearDown(auth.dispose);
  return SupabaseHostedDatabase(
    authService: auth,
    postgrest: postgrest,
    rpc: rpc,
  );
}

void main() {
  test('apply records an effect once (applied == true)', () async {
    final db = _build(_StubPostgrest(), _StubRpc());

    final result = await db.apply(
      const HostedOperation(
        kind: 'receiveEntry',
        idempotencyKey: 'k1',
        payload: {'pieces': 5},
      ),
    );

    expect(result.applied, isTrue);
    expect(result.idempotencyKey, 'k1');
    expect(result.confirmedState['pieces'], 5);
  });

  test('replaying the same key is a no-op: applied == false, state preserved',
      () async {
    final postgrest = _StubPostgrest();
    final db = _build(postgrest, _StubRpc());

    const op = HostedOperation(
      kind: 'receiveEntry',
      idempotencyKey: 'k1',
      payload: {'pieces': 5},
    );

    final first = await db.apply(op);
    final second = await db.apply(op);

    expect(first.applied, isTrue);
    expect(second.applied, isFalse);
    // The replay returns the state the first application recorded.
    expect(second.confirmedState['pieces'], 5);
  });

  test('apply is session-gated', () async {
    final db = _build(_StubPostgrest(), _StubRpc(), signedIn: false);

    expect(
      () => db.apply(
        const HostedOperation(kind: 'receiveEntry', idempotencyKey: 'k1'),
      ),
      throwsA(isA<NotAuthenticatedException>()),
    );
  });

  test('readConfirmed returns stored state, else throws not-found', () async {
    final db = _build(_StubPostgrest(), _StubRpc());

    await db.apply(
      const HostedOperation(
        kind: 'finalize',
        idempotencyKey: 'k9',
        payload: {'invoice_number': 42},
      ),
    );

    final state = await db.readConfirmed('k9');
    expect(state['invoice_number'], 42);

    expect(
      () => db.readConfirmed('missing'),
      throwsA(isA<HostedStateNotFoundException>()),
    );
  });

  test('PostgREST auth error maps to NotAuthenticatedException', () async {
    final postgrest = _StubPostgrest()
      ..insertError = const PostgrestException(
        message: 'permission denied',
        code: '42501',
      );
    final db = _build(postgrest, _StubRpc());

    expect(
      () => db.apply(
        const HostedOperation(kind: 'receiveEntry', idempotencyKey: 'k1'),
      ),
      throwsA(isA<NotAuthenticatedException>()),
    );
  });

  test('non-auth PostgREST error is surfaced unchanged (retry-safe)', () async {
    final postgrest = _StubPostgrest()
      ..insertError = const PostgrestException(
        message: 'network blip',
        code: '08006',
      );
    final db = _build(postgrest, _StubRpc());

    expect(
      () => db.apply(
        const HostedOperation(kind: 'receiveEntry', idempotencyKey: 'k1'),
      ),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('runTransaction routes staged ops to their RPC functions', () async {
    final rpc = _StubRpc();
    final db = _build(_StubPostgrest(), rpc);

    await db.runTransaction((txn) {
      txn.stage(
        const HostedOperation(
          kind: 'finalize',
          idempotencyKey: 'inv-1',
          payload: {'p_total_paise': 1000},
        ),
      );
      txn.stage(
        const HostedOperation(kind: 'void', idempotencyKey: 'void-1'),
      );
    });

    expect(rpc.calls.map((c) => c.fn), ['finalize_sale', 'void_invoice']);
    expect(rpc.calls.first.params['p_idempotency_key'], 'inv-1');
    expect(rpc.calls.first.params['p_total_paise'], 1000);
  });

  test('a throwing transaction body stages nothing (all-or-nothing)', () async {
    final rpc = _StubRpc();
    final db = _build(_StubPostgrest(), rpc);

    await expectLater(
      db.runTransaction((txn) {
        txn.stage(
          const HostedOperation(kind: 'finalize', idempotencyKey: 'inv-1'),
        );
        throw StateError('revalidation failed');
      }),
      throwsA(isA<StateError>()),
    );

    expect(rpc.calls, isEmpty);
  });

  test('runTransaction is session-gated', () async {
    final db = _build(_StubPostgrest(), _StubRpc(), signedIn: false);

    expect(
      () => db.runTransaction((_) async {}),
      throwsA(isA<NotAuthenticatedException>()),
    );
  });
}
