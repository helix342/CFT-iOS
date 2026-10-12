/// Bills tab widget test (app-ux-revamp task 12.1).
///
/// Boots [BillsListScreen] over an in-memory database seeded with finalized
/// invoices and asserts (Requirement 7.5): the bills list newest-first and a
/// read-only detail opens on tap.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/presentation/bills/bills_list_screen.dart';
import 'package:wood_cft/presentation/settings/business_profile_providers.dart';

void main() {
  late AppDatabase db;
  late int firstId;
  late int secondId;

  setUp(() async {
    db = openInMemoryDatabase();
    Future<int> seed(String number, int payable, DateTime at) async {
      final id = await db.into(db.invoices).insert(
            InvoicesCompanion.insert(
              invoiceNumber: number,
              status: InvoiceStatus.finalized,
              goodsSubtotalPaise: payable,
              taxPaise: 0,
              loadingPaise: 0,
              payablePaise: payable,
              totalCftNum: 1,
              totalCftDen: 1,
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
              crossSectionLabel: '2 × 1 in',
              lengthFt: 6,
              pieces: 10,
              exactCftNum: 1,
              exactCftDen: 1,
              rateNum: 120,
              rateDen: 1,
              lineAmountPaise: payable,
            ),
          );
      return id;
    }

    firstId = await seed('INV-1', 30000, DateTime.utc(2024, 1, 1));
    secondId = await seed('INV-2', 15000, DateTime.utc(2024, 2, 1));
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const CupertinoApp(
          home: CupertinoTabView(builder: _buildBills),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists finalized invoices newest-first', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(Key('bill_$firstId')), findsOneWidget);
    expect(find.byKey(Key('bill_$secondId')), findsOneWidget);

    // Newest (INV-2, Feb) is above INV-1 (Jan).
    final secondDy =
        tester.getTopLeft(find.byKey(Key('bill_$secondId'))).dy;
    final firstDy = tester.getTopLeft(find.byKey(Key('bill_$firstId'))).dy;
    expect(secondDy, lessThan(firstDy));
  });

  testWidgets('tapping a bill opens a read-only detail', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(Key('bill_$firstId')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bill_detail')), findsOneWidget);
    expect(find.byKey(const Key('bill_detail_payable')), findsOneWidget);
    // The line amount and the payable total are both ₹300.00 here.
    expect(find.text('₹300.00'), findsNWidgets(2));
  });
}

Widget _buildBills(BuildContext context) => const BillsListScreen();
