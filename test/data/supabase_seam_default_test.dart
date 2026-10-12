// Seam-default test (supabase-integration spec, Task 7 / Property 33).
//
// With no USE_SUPABASE --dart-define, the compile-time switch is false and the
// provider seam resolves the in-memory fakes, so the suite runs offline with no
// Supabase client constructed (Requirement 7.1, 7.3). This file deliberately
// imports neither supabase_hosted_database.dart nor the Supabase SDK, mirroring
// the fact that the default path reaches no Supabase code.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/application/auth_providers.dart';
import 'package:wood_cft/application/auth_service.dart';
import 'package:wood_cft/data/hosted_database.dart';
import 'package:wood_cft/data/hosted_database_providers.dart';

void main() {
  test('useSupabase defaults to false (no --dart-define)', () {
    expect(useSupabase, isFalse);
  });

  test('default seam resolves the in-memory fakes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(authServiceProvider), isA<FakeAuthService>());
    expect(container.read(hostedDatabaseProvider), isA<FakeHostedDatabase>());
  });

  test('fakes keep the privileged gate when explicitly signed out', () {
    // The default fake is signed-in (no-sign-in app). The gate itself is still
    // enforced: an explicitly signed-out fake refuses privileged access.
    final signedOut = FakeAuthService(); // no initial session
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(signedOut)],
    );
    addTearDown(container.dispose);
    addTearDown(signedOut.dispose);

    final hosted = container.read(hostedDatabaseProvider);
    expect(
      () => hosted.apply(
        const HostedOperation(kind: 'finalize', idempotencyKey: 'k'),
      ),
      throwsA(isA<NotAuthenticatedException>()),
    );
  });
}
