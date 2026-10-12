// Riverpod wiring tests for the hosted authoritative-database client (task 4.2).
//
// Confirms the provider defaults to a FakeHostedDatabase gated by the app-wide
// AuthService, so privileged access is refused without a session (Requirement
// 19.3) and no credential is embedded (Requirement 19.6). The provider is
// overridable for the real client later.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/application/auth_providers.dart';
import 'package:wood_cft/application/auth_service.dart';
import 'package:wood_cft/data/hosted_database.dart';
import 'package:wood_cft/data/hosted_database_providers.dart';

void main() {
  test('defaults to a FakeHostedDatabase', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final hosted = container.read(hostedDatabaseProvider);
    expect(hosted, isA<FakeHostedDatabase>());
  });

  test('is gated by the AuthService: refused when explicitly signed out', () {
    // The default fake is signed-in (no-sign-in app), so verify the gating
    // safety property with an explicitly signed-out AuthService override.
    final signedOut = FakeAuthService(); // no initial session
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(signedOut)],
    );
    addTearDown(container.dispose);
    addTearDown(signedOut.dispose);

    final hosted = container.read(hostedDatabaseProvider);
    expect(
      () => hosted.apply(
        const HostedOperation(kind: 'receiveEntry', idempotencyKey: 'k1'),
      ),
      throwsA(isA<NotAuthenticatedException>()),
    );
  });

  test('shares the AuthService session so apply succeeds once signed in',
      () async {
    final fake = FakeAuthService(ownerId: 'owner-1');
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    addTearDown(fake.dispose);

    final hosted = container.read(hostedDatabaseProvider);
    await fake.signIn();

    final result = await hosted.apply(
      const HostedOperation(kind: 'receiveEntry', idempotencyKey: 'k1'),
    );
    expect(result.applied, isTrue);
  });
}
