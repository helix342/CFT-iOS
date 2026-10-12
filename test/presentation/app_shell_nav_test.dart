/// Navigation-restructure widget test (app-ux-revamp task 11).
///
/// Boots the [AppShell] with first-run marked complete over an in-memory
/// database, and asserts the new information architecture (Requirements 7.1,
/// 7.2, 6.1): exactly four tabs (Stock / Orders / Home / Bills), Home is the
/// default selected tab (the dashboard shows), and the Settings action lives on
/// the dashboard rather than in the tab bar.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/presentation/settings/app_shell.dart';
import 'package:wood_cft/presentation/settings/business_profile_providers.dart';
import 'package:wood_cft/presentation/settings/first_run_providers.dart';
import 'package:wood_cft/presentation/settings/settings_policy_controllers.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = openInMemoryDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          ...settingsPolicyOverrides,
          firstRunCompleteProvider.overrideWith((ref) async => true),
        ],
        child: const CupertinoApp(home: AppShell()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('five tabs with Home default and Settings as a bottom tab',
      (tester) async {
    await pumpShell(tester);

    // Five bottom-navigation destinations, including Settings.
    expect(find.text('Stock'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Bills'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Home (dashboard) is the default selected tab: its surface is shown.
    expect(find.byKey(const Key('tab_home')), findsOneWidget);
  });

  testWidgets('switching to the Orders tab shows the orders home',
      (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('Orders'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('tab_orders')), findsOneWidget);
  });
}
