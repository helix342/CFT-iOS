/// Riverpod wiring for the authenticated owner session (task 4.1).
///
/// Keeps the Flutter/Riverpod dependency out of [AuthService] itself (which is
/// pure Dart and headless-testable) and exposes it to the widget tree here.
///
/// ## Fake-vs-real seam (supabase-integration spec, Task 5)
///
/// The binding is selected by the compile-time switch [useSupabase]
/// (`--dart-define=USE_SUPABASE=true`). The DEFAULT â€” no `--dart-define` â€” is
/// `false`, which resolves to the in-memory [FakeAuthService]. So `flutter
/// test` and the default offline app run with no network and never touch the
/// Supabase SDK (the real branch is dead code when [useSupabase] is `false`;
/// Requirement 7.1, 7.3). The real app builds with the switch on, where
/// [authServiceProvider] must be overridden with a bootstrapped
/// `SupabaseAuthService` whose `SupabaseAuthService.initialize` has run (wired
/// in `main.dart`, orchestrator-owned).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wood_cft/application/auth_service.dart';

/// Compile-time switch selecting the real Supabase bindings over the fakes.
///
/// `false` unless built with `--dart-define=USE_SUPABASE=true`, so tests and
/// the default app keep the fakes (Requirement 7.3, CD-4).
const bool useSupabase = bool.fromEnvironment('USE_SUPABASE');

/// The app-wide [AuthService].
///
/// Defaults to a [FakeAuthService] so the app and widget tests run without a
/// network or any embedded credential. When [useSupabase] is `true` this
/// provider is overridden in `main.dart` with a bootstrapped
/// `SupabaseAuthService`; reaching the un-overridden provider under the switch
/// is a wiring error and throws (the real service must be initialized first).
final authServiceProvider = Provider<AuthService>((ref) {
  if (useSupabase) {
    throw StateError(
      'authServiceProvider must be overridden with an initialized '
      'SupabaseAuthService when USE_SUPABASE is set (wired in main.dart).',
    );
  }
  // No interactive sign-in in this app (Requirement 2, "no sign-in"): the
  // default fake ships ALREADY signed in as the single implicit owner, so
  // finalize/sync are never blocked on a login step that does not exist. The
  // real Supabase path establishes its session via anonymous auth instead.
  final service = FakeAuthService(
    initialSession: const AuthSession(userId: 'owner'),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// The current [AuthSession] (or `null`), reactive to sign-in/sign-out.
///
/// Seeds the current [AuthService.session] and then tracks
/// [AuthService.sessionChanges], so widgets rebuild on every transition.
final authSessionProvider =
    NotifierProvider<AuthSessionNotifier, AuthSession?>(AuthSessionNotifier.new);

/// Keeps the latest [AuthSession] in sync with the [AuthService] stream.
///
/// Reads the present session for the initial value and then updates [state] on
/// every [AuthService.sessionChanges] event, so consumers rebuild on each
/// transition. The subscription is torn down with the provider.
class AuthSessionNotifier extends Notifier<AuthSession?> {
  @override
  AuthSession? build() {
    final service = ref.watch(authServiceProvider);
    final sub = service.sessionChanges.listen((session) => state = session);
    ref.onDispose(sub.cancel);
    return service.session;
  }
}

/// Whether a privileged hosted action is currently permitted.
///
/// `true` exactly when an authenticated session exists. Finalize/sync UI can
/// watch this to gate privileged affordances (Requirement 19.3).
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authSessionProvider) != null;
});
