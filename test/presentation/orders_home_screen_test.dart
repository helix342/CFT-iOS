/// Orders tab widget test (app-ux-revamp task 9.1).
///
/// Boots [OrdersHomeScreen] over an in-memory database and asserts
/// (Requirements 4.1, 4.3):
///
///   * a seeded resumable saved order appears in the list;
///   * tapping "New order" starts a workflow and pushes the build screen;
///   * tapping a saved order resumes it and pushes the build screen with its
///     staged lines restored.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/saved_orders_dao.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/presentation/orders/orders_home_screen.dart';
import 'package:wood_cft/presentation/settings/business_profile_providers.dart';

void main() {
  late AppDatabase db;
  late int varietyId;
  late int csId;

  setUp(() async {
    db = openInMemoryDatabase();
    varietyId = await db.into(db.woodVarieties).insert(
          WoodVarietiesCompanion.insert(
            name: 'Teak',
            createdAt: DateTime.utc(2024, 1, 1),
          ),
        );
    csId = await db.into(db.crossSections).insert(
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
            confirmedBalancePieces: const Value(100),
          ),
        );
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

  testWidgets('a resumable saved order appears and resumes its lines',
      (tester) async {
    final dao = SavedOrdersDao(db);
    final id = await dao.createDraft(title: 'Walk-in');
    await dao.replaceRequestLines(id, [
      SavedRequestLine(
        varietyId: varietyId,
        crossSectionId: csId,
        lengthFt: 6,
        qty: 4,
      ),
    ]);

    await pumpScreen(tester);

    expect(find.byKey(Key('saved_order_$id')), findsOneWidget);
    expect(find.text('Walk-in'), findsOneWidget);

    await tester.tap(find.byKey(Key('saved_order_$id')));
    await tester.pumpAndSettle();

    // The build screen opened with the staged line restored.
    expect(find.text('Build order'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('staged_line_0')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('staged_line_0')), findsOneWidget);
  });

  testWidgets('new order starts a workflow and opens the build screen',
      (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(const Key('saved_orders_empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('new_order_button')));
    await tester.pumpAndSettle();

    expect(find.text('Build order'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('staged_lines_empty')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('staged_lines_empty')), findsOneWidget);
  });
}

Widget _buildHome(BuildContext context) => const OrdersHomeScreen();
