/// Riverpod wiring for the hosted authoritative-database client (task 4.2).
///
/// Keeps the Flutter/Riverpod dependency out of [HostedDatabase] itself (which
/// is pure Dart and headless-testable) and exposes it to the widget tree and
/// services here.
///
/// ## Fake-vs-real seam (supabase-integration spec, Task 5)
///
/// The binding is selected by the compile-time switch [useSupabase]
/// (`--dart-define=USE_SUPABASE=true`). The DEFAULT — no `--dart-define` — is
/// `false`, resolving to the in-memory [FakeHostedDatabase] gated by the
/// app-wide `AuthService`. So the app, `SyncService`, and widget tests run
/// without a network or any embedded credential, and this file does NOT import
/// the Supabase SDK, so no test transitively loads it (Requirement 7.1, 7.3,
/// Property 33).
///
/// When [useSupabase] is `true`, [hostedDatabaseProvider] is overridden in
/// `main.dart` (orchestrator-owned) with a `SupabaseHostedDatabase` built from
/// the initialized client; reaching the un-overridden provider under the switch
/// is a wiring error and throws.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wood_cft/application/auth_providers.dart';
import 'package:wood_cft/data/hosted_database.dart';

/// The app-wide [HostedDatabase].
///
/// Defaults to a [FakeHostedDatabase] wired to the current `AuthService`, so
/// the app, `SyncService`, and widget tests run without a network or any
/// embedded credential (task 4.2). Overridden in `main.dart` with the real
/// `SupabaseHostedDatabase` when [useSupabase] is set.
final hostedDatabaseProvider = Provider<HostedDatabase>((ref) {
  if (useSupabase) {
    throw StateError(
      'hostedDatabaseProvider must be overridden with a SupabaseHostedDatabase '
      'when USE_SUPABASE is set (wired in main.dart).',
    );
  }
  final auth = ref.watch(authServiceProvider);
  return FakeHostedDatabase(authService: auth);
});
