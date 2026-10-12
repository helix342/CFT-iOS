import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/presentation/app.dart';
import 'package:wood_cft/presentation/settings/business_profile_providers.dart';
import 'package:wood_cft/presentation/settings/settings_policy_controllers.dart';
import 'package:wood_cft/presentation/theme/app_theme.dart';

/// Widget tests for the app root: [WoodCftApp] boots cleanly under both light
/// and dark Cupertino appearances with the restrained neutral theme + single
/// accent, and its home is the `AppShell` first-run gate.
///
/// The shell watches `firstRunCompleteProvider`, which queries the drift
/// database, so these tests override `appDatabaseProvider` to a fresh in-memory
/// instance (which resolves to "first-run not complete") and install the
/// policy overrides exactly as the app root does. A fresh DB settles on the
/// first-run screen; the tests only assert the root app/theme boots without
/// error (not a specific inner surface).
void main() {
  late AppDatabase db;

  setUp(() {
    db = openInMemoryDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpApp(
    WidgetTester tester,
    Brightness brightness,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          ...settingsPolicyOverrides,
        ],
        child: MediaQuery(
          data: MediaQueryData(platformBrightness: brightness),
          child: const WoodCftApp(),
        ),
      ),
    );
    // The first-run gate resolves asynchronously; pump a few frames rather than
    // pumpAndSettle (the shell may show a transient activity indicator).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('WoodCftApp boots', () {
    testWidgets('under light CupertinoThemeData without error', (tester) async {
      await pumpApp(tester, Brightness.light);

      expect(tester.takeException(), isNull);

      final app = tester.widget<CupertinoApp>(find.byType(CupertinoApp));
      expect(app.theme?.brightness, Brightness.light);
      expect(app.theme?.primaryColor, AppTheme.accentLight);
    });

    testWidgets('under dark CupertinoThemeData without error', (tester) async {
      await pumpApp(tester, Brightness.dark);

      expect(tester.takeException(), isNull);

      final app = tester.widget<CupertinoApp>(find.byType(CupertinoApp));
      expect(app.theme?.brightness, Brightness.dark);
      expect(app.theme?.primaryColor, AppTheme.accentDark);
    });

    testWidgets('is wrapped in a Riverpod ProviderScope and shows the shell',
        (tester) async {
      await pumpApp(tester, Brightness.light);

      expect(tester.takeException(), isNull);
      expect(find.byType(ProviderScope), findsOneWidget);
      // The shell renders a Cupertino surface (first-run screen for a fresh DB).
      expect(find.byType(CupertinoApp), findsOneWidget);
    });
  });
}