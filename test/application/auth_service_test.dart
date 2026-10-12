// Unit tests for the authenticated owner session (task 4.1).
//
// These pin the gate semantics for privileged Hosted_Database access
// (Requirement 19.3) and the credential-free contract (Requirement 19.6):
//   * a privileged action is refused with no session;
//   * it is permitted after sign-in;
//   * sign-out clears the session;
//   * the session-change stream reflects every transition.
//
// Pure-Dart + the test matchers via flutter_test; no widgets are pumped, and
// the headless FakeAuthService runs on Windows without a network.

import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/application/auth_service.dart';

void main() {
  late FakeAuthService auth;

  setUp(() => auth = FakeAuthService(ownerId: 'owner-1'));
  tearDown(() => auth.dispose());

  group('initial state (signed out)', () {
    test('starts signed out with no session', () {
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.session, isNull);
    });

    test('requireSession refuses a privileged action without a session', () {
      expect(
        () => auth.requireSession('finalize'),
        throwsA(isA<NotAuthenticatedException>()),
      );
    });

    test('refusal names the attempted action', () {
      expect(
        () => auth.requireSession('finalize'),
        throwsA(
          isA<NotAuthenticatedException>().having(
            (e) => e.toString(),
            'message',
            contains('finalize'),
          ),
        ),
      );
    });
  });

  group('sign-in permits privileged access', () {
    test('signIn establishes an authenticated session', () async {
      final session = await auth.signIn();

      expect(session.userId, 'owner-1');
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.session, session);
    });

    test('requireSession returns the session once signed in', () async {
      final session = await auth.signIn();

      expect(auth.requireSession('finalize'), session);
    });
  });

  group('sign-out clears the session', () {
    test('signOut returns to the signed-out state', () async {
      await auth.signIn();
      await auth.signOut();

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.session, isNull);
    });

    test('privileged action is refused again after sign-out', () async {
      await auth.signIn();
      await auth.signOut();

      expect(
        () => auth.requireSession('sync'),
        throwsA(isA<NotAuthenticatedException>()),
      );
    });

    test('signOut is a no-op when already signed out', () async {
      await expectLater(auth.signOut(), completes);
      expect(auth.isAuthenticated, isFalse);
    });
  });

  group('session-change stream reflects transitions', () {
    test('emits the session on sign-in and null on sign-out', () async {
      final emissions = <AuthSession?>[];
      final sub = auth.sessionChanges.listen(emissions.add);

      final session = await auth.signIn();
      await auth.signOut();
      // Allow the broadcast events to be delivered.
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(emissions, [session, null]);
    });

    test('does not emit when signOut is a no-op', () async {
      final emissions = <AuthSession?>[];
      final sub = auth.sessionChanges.listen(emissions.add);

      await auth.signOut();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(emissions, isEmpty);
    });
  });

  group('credential-free contract', () {
    test('a pre-seeded session carries only a non-secret owner id', () {
      final seeded = FakeAuthService(
        initialSession: const AuthSession(userId: 'owner-x'),
      );
      addTearDown(seeded.dispose);

      expect(seeded.isAuthenticated, isTrue);
      expect(seeded.session?.userId, 'owner-x');
    });

    test('AuthSession equality is by owner id', () {
      expect(
        const AuthSession(userId: 'a'),
        const AuthSession(userId: 'a'),
      );
      expect(
        const AuthSession(userId: 'a'),
        isNot(const AuthSession(userId: 'b')),
      );
    });
  });
}
