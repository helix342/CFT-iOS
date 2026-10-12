/// Widget tests for the Settings -> "Price matrix" screen (task 7.2).
///
/// Boots the [PriceMatrixScreen] with the drift database overridden to an
/// in-memory instance seeded with one variety and two cross-sections and an
/// empty (missing) rate scaffold, then asserts the editable grid behaviour from
/// design.md -> Screen Flows, Settings and Requirements 4.3, 4.5, 4.6, 17.14:
///
///   * every variety × cross-section cell renders (Req 4.3);
///   * an unpriced cell shows a VISIBLE missing marker (Req 4.5);
///   * typing a rupee amount into a cell and committing persists it as an exact
///     rate through [PricingService] (re-read confirms the value), and the grid
///     shows the formatted rate;
///   * clearing a cell marks it missing again (Req 4.5);
///   * the screen never blocks on missing rates — receiving is allowed before
///     prices (Req 4.6 / 17.13), so a fully-blank matrix is a valid state.
library;

import 'package:drift/drift.dart' show Value;
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

  // Seeded ids (deterministic): one variety, two cross-sections.
  const varietyId = 1;
  const reaperId = 1; // 2 × 1 Reaper
  const plankId = 2; // 3 × 1 Plank

  setUp(() async {
    db = openInMemoryDatabase();

    await db.into(db.woodVarieties).insert(
          WoodVarietiesCompanion.insert(
            id: const Value(varietyId),
            name: 'Mahogany',
            createdAt: DateTime.utc(2024, 1, 1),
          ),
        );
    await db.into(db.crossSections).insert(
          CrossSectionsCompanion.insert(
            id: const Value(reaperId),
            widthIn: 2,
            thicknessIn: 1,
            category: CategoryKind.reaper,
            bunchSize: 10,
          ),
        );
    await db.into(db.crossSections).insert(
          CrossSectionsCompanion.insert(
            id: const Value(plankId),
            widthIn: 3,
            thicknessIn: 1,
            category: CategoryKind.plank,
            bunchSize: 1,
          ),
        );

    // Scaffold empty (missing) rate cells for the variety across both
    // cross-sections — mirrors what onVarietyAdded does (Req 4.4).
    final service = PricingService(PriceRateRepository(db));
    await service.onVarietyAdded(
      varietyId: varietyId,
      crossSectionIds: const [reaperId, plankId],
    );
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

  testWidgets('renders a cell for every variety × cross-section (Req 4.3)', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Price matrix'), findsOneWidget);
    expect(find.text('Mahogany'), findsOneWidget);
    expect(find.text('2 × 1 in'), findsOneWidget);
    expect(find.text('3 × 1 in'), findsOneWidget);

    expect(
      find.byKey(const Key('price_cell_${varietyId}_$reaperId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('price_cell_${varietyId}_$plankId')),
      findsOneWidget,
    );
  });

  testWidgets('unpriced cells show a visible missing marker (Req 4.5)', (
    tester,
  ) async {
    await pumpScreen(tester);

    // Both cells start missing: icon + "Missing" text, not colour alone.
    expect(
      find.byKey(const Key('price_missing_${varietyId}_$reaperId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('price_missing_${varietyId}_$plankId')),
      findsOneWidget,
    );
    expect(find.text('Missing'), findsNWidgets(2));
    // Summary count is shown.
    expect(find.text('2 rates missing'), findsOneWidget);
  });

  testWidgets(
    'entering a rate into a cell persists it via PricingService (Req 4.1)',
    (tester) async {
      await pumpScreen(tester);

      // Open the editor for the reaper cell.
      await tester.tap(
        find.byKey(const Key('price_cell_${varietyId}_$reaperId')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('price_editor_field')),
        '150.75',
      );
      await tester.tap(find.byKey(const Key('price_editor_save')));
      await tester.pumpAndSettle();

      // The grid now shows the formatted rate and the missing marker is gone.
      expect(
        find.byKey(const Key('price_value_${varietyId}_$reaperId')),
        findsOneWidget,
      );
      expect(find.text('₹150.75'), findsOneWidget);
      expect(
        find.byKey(const Key('price_missing_${varietyId}_$reaperId')),
        findsNothing,
      );

      // Re-read through a fresh service: the exact rational 15075/100 persisted.
      final service = PricingService(PriceRateRepository(db));
      final rate = await service.rateFor(
        varietyId: varietyId,
        crossSectionId: reaperId,
      );
      expect(rate, Rational(BigInt.from(15075), BigInt.from(100)));
    },
  );

  testWidgets('clearing a cell marks it missing again (Req 4.5)', (
    tester,
  ) async {
    // Pre-set a rate so the cell starts priced.
    final service = PricingService(PriceRateRepository(db));
    await service.setRate(
      varietyId: varietyId,
      crossSectionId: plankId,
      rate: Rational(BigInt.from(200)),
    );

    await pumpScreen(tester);
    expect(find.text('₹200'), findsOneWidget);

    // Open the editor and clear.
    await tester.tap(
      find.byKey(const Key('price_cell_${varietyId}_$plankId')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('price_editor_clear')));
    await tester.pumpAndSettle();

    // The cell is missing again in the grid and in storage.
    expect(
      find.byKey(const Key('price_missing_${varietyId}_$plankId')),
      findsOneWidget,
    );
    final rate = await service.rateFor(
      varietyId: varietyId,
      crossSectionId: plankId,
    );
    expect(rate, isNull);
  });

  testWidgets(
    'invalid input is rejected without persisting a rate',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(
        find.byKey(const Key('price_cell_${varietyId}_$reaperId')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('price_editor_field')),
        'abc',
      );
      await tester.tap(find.byKey(const Key('price_editor_save')));
      await tester.pumpAndSettle();

      // Editor stays open with an error; nothing persisted (cell still missing).
      expect(find.byKey(const Key('price_editor_error')), findsOneWidget);

      final service = PricingService(PriceRateRepository(db));
      final rate = await service.rateFor(
        varietyId: varietyId,
        crossSectionId: reaperId,
      );
      expect(rate, isNull);
    },
  );
}
