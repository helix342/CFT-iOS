/// Widget tests for the Settings -> "Business profile" screen (task 13.1).
///
/// Boots the [BusinessProfileScreen] with the drift database overridden to an
/// in-memory instance and asserts:
///   * the form renders with no assumed business name (Requirement 18.2) and
///     no fabricated GSTIN (Requirement 18.5);
///   * editing the name field and tapping Save persists through the repository
///     (round-trips to the singleton store).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/business_settings_repository.dart';
import 'package:wood_cft/presentation/settings/business_profile_providers.dart';
import 'package:wood_cft/presentation/settings/business_profile_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = openInMemoryDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const CupertinoApp(home: BusinessProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the business-profile form with blank defaults', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Business profile'), findsOneWidget);
    expect(find.byKey(const Key('business_name_field')), findsOneWidget);
    expect(find.byKey(const Key('business_gstin_field')), findsOneWidget);
    expect(
      find.byKey(const Key('business_invoice_prefix_field')),
      findsOneWidget,
    );

    // No assumed business name is pre-filled (Req 18.2); no fabricated GSTIN
    // (Req 18.5).
    final nameField = tester.widget<CupertinoTextField>(
      find.descendant(
        of: find.byKey(const Key('business_name_field')),
        matching: find.byType(CupertinoTextField),
      ),
    );
    expect(nameField.controller?.text, isEmpty);
    expect(find.text('Zenith Systems'), findsNothing);

    final gstinField = tester.widget<CupertinoTextField>(
      find.descendant(
        of: find.byKey(const Key('business_gstin_field')),
        matching: find.byType(CupertinoTextField),
      ),
    );
    expect(gstinField.controller?.text, isEmpty);
  });

  testWidgets('editing the name field and saving persists the profile', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('business_name_field')),
        matching: find.byType(CupertinoTextField),
      ),
      'Timber Mart',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('business_invoice_prefix_field')),
        matching: find.byType(CupertinoTextField),
      ),
      'TM-',
    );

    await tester.tap(
      find.byKey(const Key('business_profile_save_button')),
    );
    await tester.pumpAndSettle();

    // Verify the edit reached storage via a fresh repository read.
    final saved = await BusinessSettingsRepository(db).load();
    expect(saved.name, 'Timber Mart');
    expect(saved.invoicePrefix, 'TM-');
    expect(saved.gstin, isNull);
  });
}
