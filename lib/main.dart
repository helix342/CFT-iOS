import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wood_cft/application/auth_providers.dart';
import 'package:wood_cft/application/supabase_auth_service.dart';
import 'package:wood_cft/data/hosted_database_providers.dart';
import 'package:wood_cft/data/supabase_hosted_database.dart';
import 'package:wood_cft/presentation/app.dart';
import 'package:wood_cft/presentation/settings/app_shell.dart';

/// Application entry point.
///
/// Boots the Cupertino app wrapped in a Riverpod [ProviderScope]. The scope
/// always installs [AppShell.rootOverrides] (the editable Settings policy
/// controllers). When the app is built with `--dart-define=USE_SUPABASE=true`
/// it ALSO initializes the Supabase client and overrides the hosted-database /
/// auth providers with the real `SupabaseHostedDatabase` / `SupabaseAuthService`
/// (anonymous session). The default build (no define) keeps the in-memory
/// fakes, so the app runs fully offline against the local SQLite cache.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final overrides = [...AppShell.rootOverrides];

  if (useSupabase) {
    // Initialize the Supabase SDK from --dart-define config, establish the
    // non-interactive (anonymous) owner session, and bind the real hosted
    // store + auth behind the existing interfaces.
    await initializeSupabase();
    final auth = SupabaseAuthService(port: SupabaseGoTrueAuthPort());
    await auth.initialize();
    final hosted = SupabaseHostedDatabase(
      authService: auth,
      postgrest: SupabaseClientPostgrestPort(),
      rpc: SupabaseClientRpcPort(),
    );
    overrides.add(authServiceProvider.overrideWithValue(auth));
    overrides.add(hostedDatabaseProvider.overrideWithValue(hosted));
  }

  runApp(
    ProviderScope(
      overrides: overrides,
      child: const WoodCftApp(),
    ),
  );
}
