/// Vertical-layout widget tests for the Price matrix (app-ux-revamp task 6.1).
///
/// Complements `price_matrix_screen_test.dart` by asserting the layout is a
/// vertically-scrolling list of rate rows (Requirement 5.1), one row per
/// variety x cross-section grouped under a per-variety header, and that edit /
/// clear still persists through [PricingService] in the new layout
/// (Requirement 5.2).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/pricing_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/price_rate_repository.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/presentation/settings/business_profile_providers.dart';
import 'package:wood_cft/presentation/settings/price_matrix_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = openInMemoryDatabase();
    // Two varieties x two cross-sections => a 4-row vertical list.
    final teak = await db.into(db.woodVarieties).insert(
          WoodVarietiesCompanion.insert(
            name: 'Teak',
            createdAt: DateTime.utc(2024, 1, 1),
          ),
        );
    final rose = await db.into(db.woodVarieties).insert(
          WoodVarietiesCompanion.insert(
            name: 'Rosewood',
            createdAt: DateTime.utc(2024, 1, 1),
          ),
        );
    final reaper = await db.into(db.crossSections).insert(
          CrossSectionsCompanion.insert(
            widthIn: 2,
            thicknessIn: 1,
            category: CategoryKind.reaper,
            bunchSize: 10,
          ),
        );
    final plank = await db.into(db.crossSections).insert(
          CrossSectionsCompanion.insert(
            widthIn: 3,
            thicknessIn: 1,
            category: CategoryKind.plank,
            bunchSize: 1,
          ),
        );
    final service = PricingService(PriceRateRepository(db));
    for (final v in [teak, rose]) {
      await service.onVarietyAdded(
        varietyId: v,
        crossSectionIds: [reaper, plank],
      );
    }
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const CupertinoApp(home: PriceMatrixScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders a vertically-scrolling list of rate rows (Req 5.1)',
      (tester) async {
    await pumpScreen(tester);

    final listFinder = find.byKey(const Key('price_matrix_list'));
    expect(listFinder, findsOneWidget);

    final listView = tester.widget<ListView>(listFinder);
    expect(listView.scrollDirection, Axis.vertical);

    // Each variety heading appears once, above its rows.
    expect(find.text('Teak'), findsOneWidget);
    expect(find.text('Rosewood'), findsOneWidget);

    // One tappable rate row per variety x cross-section (4 total).
    for (final cellKey in [
      'price_cell_1_1',
      'price_cell_1_2',
      'price_cell_2_1',
      'price_cell_2_2',
    ]) {
      expect(find.byKey(Key(cellKey)), findsOneWidget);
    }
  });

  testWidgets('editing a row persists the rate in the vertical layout (Req 5.2)',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('price_cell_2_1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('price_editor_field')),
      '175.25',
    );
    await tester.tap(find.byKey(const Key('price_editor_save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('price_value_2_1')), findsOneWidget);
    expect(find.text('₹175.25'), findsOneWidget);

    final service = PricingService(PriceRateRepository(db));
    final rate = await service.rateFor(varietyId: 2, crossSectionId: 1);
    expect(rate, Rational(BigInt.from(17525), BigInt.from(100)));
  });
}
