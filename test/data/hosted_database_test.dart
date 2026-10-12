// Unit tests for the hosted authoritative-database client (task 4.2).
//
// These pin the hosted client's privileged-access, idempotency, and
// all-or-nothing transaction semantics against the in-memory FakeHostedDatabase
// so SyncService (4.3) and finalize (11.x) can be built and tested on Windows
// with no network:
//   * a privileged apply/transaction/read without a session is refused via
//     AuthService (Requirement 19.3);
//   * with a session it succeeds;
//   * applying the same idempotency key twice yields exactly one effect
//     (Requirement 19.9, 19.10);
//   * a transaction whose body throws rolls back with no partial effect
//     (Requirement 12.4);
//   * no credential is embedded (Requirement 19.6) — the fake carries none.
//
// Pure-Dart + the flutter_test matchers; no widgets are pumped.

import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/application/auth_service.dart';
import 'package:wood_cft/data/hosted_database.dart';

void main() {
  late FakeAuthService auth;
  late FakeHostedDatabase hosted;

  setUp(() {
    auth = FakeAuthService(ownerId: 'owner-1');
    hosted = FakeHostedDatabase(authService: auth);
  });
  tearDown(() => auth.dispose());

  HostedOperation op(String key, {String kind = 'receiveEntry'}) =>
      HostedOperation(
        kind: kind,
        idempotencyKey: key,
        payload: {'pieces': 30, 'key': key},
      );

  group('privileged access requires an authenticated session (Req 19.3)', () {
    test('apply without a session is refused', () {
      expect(
        () => hosted.apply(op('k1')),
        throwsA(isA<NotAuthenticatedException>()),
      );
    });

    test('runTransaction without a session is refused', () {
      expect(
        () => hosted.runTransaction((txn) async {}),
        throwsA(isA<NotAuthenticatedException>()),
      );
    });

    test('readConfirmed without a session is refused', () {
      expect(
        () => hosted.readConfirmed('k1'),
        throwsA(isA<NotAuthenticatedException>()),
      );
    });

    test('refusal body did not touch the store', () async {
      await expectLater(
        hosted.apply(op('k1')),
        throwsA(isA<NotAuthenticatedException>()),
      );
      expect(hosted.appliedCount, 0);
    });
  });

  group('with a session privileged calls succeed', () {
    setUp(() => auth.signIn());

    test('apply records the effect and confirmed state', () async {
      final result = await hosted.apply(op('k1'));

      expect(result.applied, isTrue);
      expect(result.idempotencyKey, 'k1');
      expect(result.confirmedState['pieces'], 30);
      expect(hosted.hasApplied('k1'), isTrue);
      expect(hosted.appliedCount, 1);
    });

    test('readConfirmed returns the applied state', () async {
      await hosted.apply(op('k1'));

      final state = await hosted.readConfirmed('k1');
      expect(state['pieces'], 30);
    });

    test('readConfirmed throws for an unknown key', () {
      expect(
        () => hosted.readConfirmed('missing'),
        throwsA(isA<HostedStateNotFoundException>()),
      );
    });

    test('runTransaction commits staged ops and returns the body value',
        () async {
      final invoiceNo = await hosted.runTransaction((txn) async {
        txn.stage(op('deduct-1'));
        txn.stage(op('invoice-1', kind: 'finalize'));
        return 42;
      });

      expect(invoiceNo, 42);
      expect(hosted.hasApplied('deduct-1'), isTrue);
      expect(hosted.hasApplied('invoice-1'), isTrue);
      expect(hosted.appliedCount, 2);
    });

    test('the transaction handle carries the authenticated session', () async {
      await hosted.runTransaction((txn) async {
        expect(txn.session.userId, 'owner-1');
      });
    });
  });

  group('idempotency: same key applied twice = exactly one effect (Req 19.9)',
      () {
    setUp(() => auth.signIn());

    test('second apply of the same key is a no-op replay', () async {
      final first = await hosted.apply(op('dup'));
      final second = await hosted.apply(op('dup'));

      expect(first.applied, isTrue);
      expect(second.applied, isFalse);
      // Only one distinct effect exists.
      expect(hosted.appliedCount, 1);
      // The duplicate replay still returns the original confirmed state.
      expect(second.confirmedState['pieces'], 30);
    });

    test('the first-applied state wins and is not overwritten by a replay',
        () async {
      await hosted.apply(
        const HostedOperation(
          kind: 'receiveEntry',
          idempotencyKey: 'dup',
          payload: {'pieces': 30},
        ),
      );
      final replay = await hosted.apply(
        const HostedOperation(
          kind: 'receiveEntry',
          idempotencyKey: 'dup',
          payload: {'pieces': 999}, // would be wrong if it overwrote
        ),
      );

      expect(replay.applied, isFalse);
      expect(replay.confirmedState['pieces'], 30);
      final state = await hosted.readConfirmed('dup');
      expect(state['pieces'], 30);
    });

    test('duplicate keys staged within one transaction collapse to one effect',
        () async {
      await hosted.runTransaction((txn) async {
        txn.stage(op('dup'));
        txn.stage(op('dup'));
      });

      expect(hosted.appliedCount, 1);
    });
  });

  group('transactions are all-or-nothing (Req 12.4)', () {
    setUp(() => auth.signIn());

    test('a throwing body rolls back with no partial effect', () async {
      await expectLater(
        hosted.runTransaction((txn) async {
          txn.stage(op('a'));
          txn.stage(op('b'));
          throw StateError('validation failed');
        }),
        throwsA(isA<StateError>()),
      );

      // Neither staged op was committed.
      expect(hosted.hasApplied('a'), isFalse);
      expect(hosted.hasApplied('b'), isFalse);
      expect(hosted.appliedCount, 0);
    });

    test('a rolled-back key can be re-applied cleanly afterwards', () async {
      await expectLater(
        hosted.runTransaction((txn) async {
          txn.stage(op('a'));
          throw StateError('boom');
        }),
        throwsA(isA<StateError>()),
      );

      // The failed transaction left no trace, so a later apply succeeds.
      final result = await hosted.apply(op('a'));
      expect(result.applied, isTrue);
      expect(hosted.appliedCount, 1);
    });

    test('a prior committed effect survives a later failed transaction',
        () async {
      await hosted.apply(op('existing'));

      await expectLater(
        hosted.runTransaction((txn) async {
          txn.stage(op('new'));
          throw StateError('boom');
        }),
        throwsA(isA<StateError>()),
      );

      expect(hosted.hasApplied('existing'), isTrue);
      expect(hosted.hasApplied('new'), isFalse);
      expect(hosted.appliedCount, 1);
    });
  });
}
