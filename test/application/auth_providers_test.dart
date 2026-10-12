// Riverpod wiring tests for the authenticated owner session (task 4.1).
//
// Confirms the providers expose the AuthService and reflect sign-in/sign-out,
// keeping the gate (Requirement 19.3) reactive for the widget tree while the
// service stays headless.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/application/auth_providers.dart';
import 'package:wood_cft/application/auth_service.dart';

void main() {
  // This app has NO interactive sign-in (Requirement 2). The default
  // FakeAuthService therefore ships ALREADY signed in as the single implicit
  // owner so finalize/sync are never blocked on a login step that does not
  // exist. (The "refused without a session" safety property is still covered
  // below with an explicitly signed-out fake.)
  test('defaults to a FakeAuthService that starts signed in (no sign-in app)',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(authServiceProvider);
    expect(service, isA<FakeAuthService>());
    expect(service.isAuthenticated, isTrue);
  });

  test('authSessionProvider seeds the implicit owner session', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(authSessionProvider), isNotNull);
    expect(container.read(isAuthenticatedProvider), isTrue);
  });

  test('an explicitly signed-out fake still refuses privileged access', () {
    final fake = FakeAuthService(); // no initial session
    addTearDown(fake.dispose);
    expect(fake.isAuthenticated, isFalse);
    expect(fake.requireSession, throwsA(isA<NotAuthenticatedException>()));
  });

  test('seeds a pre-existing session on first read', () {
    final fake = FakeAuthService(
      initialSession: const AuthSession(userId: 'owner-x'),
    );
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    addTearDown(fake.dispose);

    expect(container.read(authSessionProvider)?.userId, 'owner-x');
    expect(container.read(isAuthenticatedProvider), isTrue);
  });

  test('reflects sign-in then sign-out through the provider', () async {
    final fake = FakeAuthService(ownerId: 'owner-1');
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    addTearDown(fake.dispose);

    // Keep the provider (and its stream subscription) alive for the test.
    final sub = container.listen(authSessionProvider, (_, _) {});
    addTearDown(sub.close);

    expect(container.read(authSessionProvider), isNull);

    await fake.signIn();
    await _pump();
    expect(container.read(authSessionProvider)?.userId, 'owner-1');
    expect(container.read(isAuthenticatedProvider), isTrue);

    await fake.signOut();
    await _pump();
    expect(container.read(authSessionProvider), isNull);
    expect(container.read(isAuthenticatedProvider), isFalse);
  });
}

/// Lets pending broadcast-stream events and provider rebuilds settle.
Future<void> _pump() => Future<void>.delayed(const Duration(milliseconds: 10));
