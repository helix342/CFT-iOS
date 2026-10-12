/// Widget + wiring tests for the Settings tab surfaces and first-run setup
/// (task 15.2).
///
/// Covers the three verification goals for this task:
///   * Settings renders the current policy + loading tiers and the business /
///     price links;
///   * editing the tax mode and the 8â€“9 ft allocation toggle updates the
///     EXPOSED task-15.1 policy providers (through the editable controllers and
///     their overrides) so billing/allocation readers see the change;
///   * the first-run flow completes with the minimum input (a business name)
///     and seeds the catalog with ZERO stock and prices defaulted to Rs 480.
///
/// The drift database is overridden to an in-memory instance and the editable
/// policy controllers are wired to the read-only policy providers via
/// [settingsPolicyOverrides], exactly as the app root does.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/application/pricing_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/business_settings_repository.dart';
import 'package:wood_cft/data/price_rate_repository.dart';
import 'package:wood_cft/presentation/settings/business_profile_providers.dart';
import 'package:wood_cft/presentation/settings/first_run_providers.dart';
import 'package:wood_cft/presentation/settings/first_run_screen.dart';
import 'package:wood_cft/presentation/settings/policy_providers.dart';
import 'package:wood_cft/presentation/settings/settings_policy_controllers.dart';
import 'package:wood_cft/presentation/settings/settings_tab.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = openInMemoryDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  ProviderScope wrap(Widget child) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        ...settingsPolicyOverrides,
      ],
      child: CupertinoApp(home: child),
    );
  }

  group('Settings tab renders the current policy and profile', () {
    testWidgets('shows tax mode, loading tiers, allocation knobs, and links',
        (tester) async {
      await tester.pumpWidget(wrap(const SettingsTab()));
      await tester.pumpAndSettle();

      // Section links.
      expect(
        find.byKey(const Key('settings_business_profile_row')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings_price_matrix_row')),
        findsOneWidget,
      );

      // Tax mode defaults to No GST (single literal line).
      final taxControl = tester.widget<CupertinoSegmentedControl<TaxMode>>(
        find.byKey(const Key('settings_tax_mode_control')),
      );
      expect(taxControl.groupValue, TaxMode.noGst);

      // Loading tiers surfaced for the owner to read/confirm (â‚¹100 / â‚¹150).
      expect(find.byKey(const Key('settings_loading_low')), findsOneWidget);
      expect(find.byKey(const Key('settings_loading_high')), findsOneWidget);
      expect(find.textContaining('\u20B9100.00'), findsOneWidget);
      expect(find.textContaining('\u20B9150.00'), findsOneWidget);

      // Allocation knobs: 8â€“9 ft fallback OFF by default, reaper 60/30/10.
      final fallbackSwitch = tester.widget<CupertinoSwitch>(
        find.byKey(const Key('settings_allow_89ft_switch')),
      );
      expect(fallbackSwitch.value, isFalse);
      expect(
        find.byKey(const Key('settings_reaper_shares')),
        findsOneWidget,
      );
      expect(find.textContaining('60%'), findsOneWidget);
    });
  });

  group('editing Settings updates the exposed policy providers', () {
    testWidgets('tax mode selection flows to taxModeProvider', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          ...settingsPolicyOverrides,
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CupertinoApp(home: SettingsTab()),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(taxModeProvider), TaxMode.noGst);

      // Tap the "18%" segment.
      await tester.tap(find.text('18%'));
      await tester.pumpAndSettle();

      // The read-only, task-15.1 taxModeProvider now resolves the edited value.
      expect(container.read(taxModeProvider), TaxMode.eighteen);
    });

    testWidgets('8â€“9 ft toggle flows to allocationPolicyProvider',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          ...settingsPolicyOverrides,
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CupertinoApp(home: SettingsTab()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(allocationPolicyProvider).allow89ftFallback,
        isFalse,
      );

      await tester.tap(find.byKey(const Key('settings_allow_89ft_switch')));
      await tester.pumpAndSettle();

      // The allocation policy every allocator reads now has the fallback ON.
      expect(
        container.read(allocationPolicyProvider).allow89ftFallback,
        isTrue,
      );
    });
  });

  group('first-run setup', () {
    testWidgets('requires a business name before it will begin',
        (tester) async {
      await tester.pumpWidget(wrap(const FirstRunScreen()));
      await tester.pumpAndSettle();

      // The empty-state honesty note is shown.
      expect(find.byKey(const Key('first_run_empty_note')), findsOneWidget);

      // Tapping Begin with no name surfaces an error and seeds nothing.
      await tester.tap(find.byKey(const Key('first_run_begin_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('first_run_error')), findsOneWidget);

      // No catalog was seeded.
      final seeded = await CatalogSeeder(db).isSeeded();
      expect(seeded, isFalse);
    });

    testWidgets('completes with the minimum input: zero stock, prices seeded '
        'at Rs 480', (tester) async {
      await tester.pumpWidget(wrap(const FirstRunScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('first_run_name_field')),
        'Timber Mart',
      );
      await tester.enterText(
        find.byKey(const Key('first_run_invoice_prefix_field')),
        'TM-',
      );

      await tester.tap(find.byKey(const Key('first_run_begin_button')));
      await tester.pumpAndSettle();

      // The minimum profile persisted (name + prefix), GSTIN never fabricated.
      final profile = await BusinessSettingsRepository(db).load();
      expect(profile.name, 'Timber Mart');
      expect(profile.invoicePrefix, 'TM-');
      expect(profile.gstin, isNull);

      // Catalog seeded: 3 varieties Ã— 6 cross-sections Ã— 8 lengths (2â€“9 ft).
      final varieties = await db.select(db.woodVarieties).get();
      final crossSections = await db.select(db.crossSections).get();
      final stockItems = await db.select(db.stockItems).get();
      expect(varieties.length, 3);
      expect(crossSections.length, 6);
      expect(stockItems.length, 3 * 6 * 8);

      // ZERO stock: every seeded balance is zero (no fictional stock).
      expect(
        stockItems.every(
          (s) => s.confirmedBalancePieces == 0 && s.pendingBalancePieces == 0,
        ),
        isTrue,
      );

      // Prices seeded at Rs 480/CFT for every variety x cross-section
      // (3 x 6 = 18 rate rows), read back as the exact rational 480.
      final rates = await db.select(db.priceRates).get();
      expect(rates.length, 3 * 6);
      final pricing = PricingService(PriceRateRepository(db));
      final sample = await pricing.rateFor(
        varietyId: varieties.first.id,
        crossSectionId: crossSections.first.id,
      );
      expect(sample, Rational.fromInt(480));
    });

    testWidgets('seeding is idempotent (re-run does not duplicate the catalog)',
        (tester) async {
      final seeder = CatalogSeeder(db);
      await seeder.seed();
      await seeder.seed();

      final varieties = await db.select(db.woodVarieties).get();
      expect(varieties.length, 3);
    });
  });
}
