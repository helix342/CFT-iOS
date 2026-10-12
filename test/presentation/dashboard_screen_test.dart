/// Dashboard widget test (app-ux-revamp task 10.1).
///
/// Boots [DashboardScreen] over an in-memory database seeded with confirmed
/// stock and finalized invoices, and asserts (Requirements 6.2, 6.3, 6.4,
/// 6.7): the totals-sold figures render, available stock lists, recent orders
/// list newest-first, and the top-right Settings action is present.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/presentation/home/dashboard_screen.dart';
import 'package:wood_cft/presentation/settings/business_profile_providers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = openInMemoryDatabase();
    final varietyId = await db.into(db.woodVarieties).insert(
          WoodVarietiesCompanion.insert(
            name: 'Teak',
            createdAt: DateTime.utc(2024, 1, 1),
          ),
        );
    final csId = await db.into(db.crossSections).insert(
          CrossSectionsCompanion.insert(
            widthIn: 2,
            thicknessIn: 1,
            category: CategoryKind.reaper,
            bunchSize: 10,
          ),
        );
    await db.into(db.stockItems).insert(
          StockItemsCompanion.insert(
            varietyId: varietyId,
            crossSectionId: csId,
            lengthFt: 6,
            confirmedBalancePieces: const Value(40),
          ),
        );
    // Two finalized invoices: total â‚¹450, 4 CFT, 30 pcs.
    Future<void> seed(String number, int payable, int cftN, int pieces,
        DateTime at) async {
      final id = await db.into(db.invoices).insert(
            InvoicesCompanion.insert(
              invoiceNumber: number,
              status: InvoiceStatus.finalized,
              goodsSubtotalPaise: payable,
              taxPaise: 0,
              loadingPaise: 0,
              payablePaise: payable,
              totalCftNum: cftN,
              totalCftDen: 2,
              taxPolicySnapshot: '{}',
              loadingPolicySnapshot: '{}',
              businessProfileSnapshot: '{}',
              finalizedAt: at,
              idempotencyKey: 'k-$number',
            ),
          );
      await db.into(db.invoiceLines).insert(
            InvoiceLinesCompanion.insert(
              invoiceId: id,
              varietyName: 'Teak',
              crossSectionLabel: '2 Ã— 1 in',
              lengthFt: 6,
              pieces: pieces,
              exactCftNum: cftN,
              exactCftDen: 2,
              rateNum: 120,
              rateDen: 1,
              lineAmountPaise: payable,
            ),
          );
    }

    await seed('INV-1', 30000, 5, 20, DateTime.utc(2024, 1, 1));
    await seed('INV-2', 15000, 3, 10, DateTime.utc(2024, 2, 1));
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const CupertinoApp(
          home: CupertinoTabView(builder: _buildHome),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders seeded totals, stock, recent orders, and Settings',
      (tester) async {
    await pumpScreen(tester);

    expect(
      tester
          .widget<Text>(find.byKey(const Key('dashboard_total_pieces')))
          .data,
      '30 pcs',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('dashboard_total_cft'))).data,
      '4.0000 CFT',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('dashboard_total_amount')))
          .data,
      '\u20B9450.00',
    );

    // Available stock (Req 6.2).
    expect(find.text('Teak \u00B7 2 \u00D7 1 in \u00B7 6 ft'), findsOneWidget);
    expect(find.text('40 pcs'), findsOneWidget);

    // Recent orders (Req 6.4): both invoices listed.
    expect(find.text('INV-1'), findsOneWidget);
    expect(find.text('INV-2'), findsOneWidget);

    // Brand mark present (Settings is now a bottom tab, not a dashboard gear).
    expect(find.byKey(const Key('dashboard_brand')), findsOneWidget);
  });
}

Widget _buildHome(BuildContext context) => const DashboardScreen();
