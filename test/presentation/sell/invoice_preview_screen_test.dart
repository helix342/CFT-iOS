/// Widget tests for the Sell-tab invoice preview + finalize gating screen
/// (task 11.5).
///
/// These boot [InvoicePreviewScreen] with the drift database overridden to an
/// in-memory instance seeded with a 2×1 reaper SKU at 6 ft (one bunch of 10
/// pieces = 1/12 CFT each) and the `AuthService` overridden to a
/// [FakeAuthService] in either the signed-in or signed-out state. They stage a
/// structured request on the shared `draftOrderRequestsProvider` and assert:
///
///   * the preview renders the goods line, the goods subtotal, the single tax
///     line, the loading charge and the payable from the shared calculation;
///   * FINALIZE is DISABLED (with a clear reason) when signed out;
///   * FINALIZE is blocked with the service's reason when confirmed stock is
///     insufficient;
///   * a successful finalize (signed in, online, priced, in-stock) shows the
///     issued invoice number; and
///   * building/viewing the preview NEVER deducts stock (Requirement 12.1,
///     12.5, 21.21).
///
/// The hosted DB is the in-memory `FakeHostedDatabase` auto-wired to the
/// overridden `AuthService`, so these run under `flutter test` on Windows with
/// no device and no network.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/auth_providers.dart';
import 'package:wood_cft/application/auth_service.dart';
import 'package:wood_cft/application/pricing_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/price_rate_repository.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/domain/order_request.dart';
import 'package:wood_cft/presentation/sell/invoice_preview_providers.dart';
import 'package:wood_cft/presentation/sell/invoice_preview_screen.dart';

/// The seeded ids a test needs to stage a request and assert the preview.
class _Seed {
  const _Seed({
    required this.varietyId,
    required this.reaperCrossSectionId,
    required this.stockItemId,
  });

  final int varietyId;
  final int reaperCrossSectionId;
  final int stockItemId;
}

/// Seeds one active variety (Mahogany) + a 2×1 reaper cross-section and a
/// single 6 ft stock item with [confirmed] confirmed (sellable) pieces.
Future<_Seed> _seed(AppDatabase db, {required int confirmed}) async {
  final varietyId = await db.into(db.woodVarieties).insert(
        WoodVarietiesCompanion.insert(
          name: 'Mahogany',
          createdAt: DateTime.utc(2024, 1, 1),
        ),
      );
  final reaperCrossSectionId = await db.into(db.crossSections).insert(
        CrossSectionsCompanion.insert(
          widthIn: 2,
          thicknessIn: 1,
          category: CategoryKind.reaper,
          bunchSize: 10,
        ),
      );
  final stockItemId = await db.into(db.stockItems).insert(
        StockItemsCompanion.insert(
          varietyId: varietyId,
          crossSectionId: reaperCrossSectionId,
          lengthFt: 6,
          confirmedBalancePieces: Value(confirmed),
        ),
      );
  return _Seed(
    varietyId: varietyId,
    reaperCrossSectionId: reaperCrossSectionId,
    stockItemId: stockItemId,
  );
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  /// Builds a container over the seeded db with the given auth state and
  /// connectivity, optionally with a rate set for the seeded SKU.
  Future<_Seed> setUpWith({
    required int confirmed,
    required bool signedIn,
    bool online = true,
    bool withRate = true,
  }) async {
    db = openInMemoryDatabase();
    final seed = await _seed(db, confirmed: confirmed);
    if (withRate) {
      final pricing = PricingService(PriceRateRepository(db));
      await pricing.setRate(
        varietyId: seed.varietyId,
        crossSectionId: seed.reaperCrossSectionId,
        rate: Rational.fromInt(100), // ₹100 / CFT
      );
    }
    final auth = FakeAuthService(
      initialSession:
          signedIn ? const AuthSession(userId: 'owner') : null,
    );
    addTearDown(auth.dispose);
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authServiceProvider.overrideWithValue(auth),
        connectivityProvider.overrideWithValue(online),
      ],
    );
    return seed;
  }

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> stage(_Seed seed, {required int bunches}) async {
    container.read(draftOrderRequestsProvider.notifier).add(
          ExactQtyRequest(
            varietyId: seed.varietyId,
            crossSectionId: seed.reaperCrossSectionId,
            lengthFt: 6,
            quantityUnits: bunches,
          ),
        );
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CupertinoApp(home: InvoicePreviewScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty draft shows the nothing-to-bill state', (tester) async {
    await setUpWith(confirmed: 50, signedIn: true);
    await pumpScreen(tester);
    expect(find.byKey(const Key('invoice_preview_empty')), findsOneWidget);
    expect(find.byKey(const Key('invoice_preview_list')), findsNothing);
  });

  testWidgets(
      'preview shows goods line, subtotal, single tax line, loading and payable '
      'from the shared calculation (Req 12.2)', (tester) async {
    // 50 confirmed = 5 bunches; demand 3 bunches = 30 pcs = 2.5 CFT @ ₹100 =
    // ₹250 goods; No GST → ₹0 tax; 2.5 CFT < 20 → ₹100 loading; ₹350 payable.
    final seed = await setUpWith(confirmed: 50, signedIn: true);
    await stage(seed, bunches: 3);
    await pumpScreen(tester);

    expect(find.byKey(const Key('invoice_preview_list')), findsOneWidget);
    // One goods line showing the SKU, 30 pcs / 2.5000 CFT, and the amount.
    expect(find.byKey(const Key('invoice_line_0')), findsOneWidget);
    expect(find.byKey(const Key('invoice_line_0_amount')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('invoice_line_0_amount'))).data,
      '₹250.00',
    );

    // Totals block: a SINGLE tax line (No GST → ₹0.00), loading, payable.
    expect(
      tester.widget<Text>(find.byKey(const Key('invoice_total_goods'))).data,
      '₹250.00',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('invoice_total_tax'))).data,
      '₹0.00',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('invoice_total_loading'))).data,
      '₹100.00',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('invoice_total_payable'))).data,
      '₹350.00',
    );
    // The single-line tax label (never a CGST/SGST split).
    expect(find.text('No GST'), findsOneWidget);
  });

  testWidgets(
      'finalize is DISABLED with a reason when signed out — order stays a draft '
      '(Req 12.3b)', (tester) async {
    final seed = await setUpWith(confirmed: 50, signedIn: false);
    await stage(seed, bunches: 3);
    await pumpScreen(tester);

    final button = tester.widget<CupertinoButton>(
      find.byKey(const Key('invoice_finalize_button')),
    );
    expect(button.onPressed, isNull); // disabled

    // The gate reason tells the owner why and that the order stays a draft.
    expect(find.byKey(const Key('invoice_gate_reason')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('invoice_gate_reason'))).data,
      contains('Sign in to finalize'),
    );
  });

  testWidgets(
      'finalize is blocked and shows the reason when confirmed stock is '
      'insufficient (Req 12.6)', (tester) async {
    // Only 30 confirmed = 3 bunches; demand 6 bunches (60 pcs) → short.
    final seed = await setUpWith(confirmed: 30, signedIn: true);
    await stage(seed, bunches: 6);
    await pumpScreen(tester);

    // The advisory gate already flags insufficient stock and disables the
    // button.
    final button = tester.widget<CupertinoButton>(
      find.byKey(const Key('invoice_finalize_button')),
    );
    expect(button.onPressed, isNull);
    expect(
      tester.widget<Text>(find.byKey(const Key('invoice_gate_reason'))).data,
      contains('Not enough confirmed stock'),
    );
  });

  testWidgets(
      'successful finalize when signed in + online shows the issued invoice '
      'number (Req 12.2)', (tester) async {
    final seed = await setUpWith(confirmed: 50, signedIn: true);
    await stage(seed, bunches: 3);
    await pumpScreen(tester);

    final button = tester.widget<CupertinoButton>(
      find.byKey(const Key('invoice_finalize_button')),
    );
    expect(button.onPressed, isNotNull); // enabled

    await tester.tap(find.byKey(const Key('invoice_finalize_button')));
    await tester.pumpAndSettle();

    // The issued invoice banner shows the permanent number.
    expect(find.byKey(const Key('invoice_finalized_banner')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('invoice_finalized_number')))
          .data,
      'Invoice #1',
    );
  });

  testWidgets(
      'preview does NOT deduct stock — the confirmed balance is unchanged after '
      'building the preview (Req 12.1, 12.5, 21.21)', (tester) async {
    final seed = await setUpWith(confirmed: 50, signedIn: true);
    await stage(seed, bunches: 3);
    await pumpScreen(tester);

    // The preview rendered (so the whole read path ran)...
    expect(find.byKey(const Key('invoice_preview_totals')), findsOneWidget);
    // ...and the confirmed balance is still exactly what was seeded. A draft
    // preview mutates NO stock.
    final row = await (db.select(db.stockItems)
          ..where((s) => s.id.equals(seed.stockItemId)))
        .getSingle();
    expect(row.confirmedBalancePieces, 50);
  });

  testWidgets('a line missing a rate is flagged and blocks finalize (Req 4.7)',
      (tester) async {
    final seed = await setUpWith(confirmed: 50, signedIn: true, withRate: false);
    await stage(seed, bunches: 3);
    await pumpScreen(tester);

    // The line carries a missing-rate flag.
    expect(
      find.byKey(const Key('invoice_line_0_missing_rate')),
      findsOneWidget,
    );
    // Finalize is disabled with the missing-rate reason.
    final button = tester.widget<CupertinoButton>(
      find.byKey(const Key('invoice_finalize_button')),
    );
    expect(button.onPressed, isNull);
    expect(
      tester.widget<Text>(find.byKey(const Key('invoice_gate_reason'))).data,
      contains('missing a rate'),
    );
  });
}
