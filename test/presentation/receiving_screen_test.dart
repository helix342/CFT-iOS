/// Widget tests for the Stock-tab compact length-grid receiving screen
/// (task 5.2).
///
/// These boot [ReceivingScreen] with the drift database overridden to an
/// in-memory instance seeded with a reaper 2×1 cross-section and a plank 3×1
/// cross-section (each with varieties and 2–9 ft stock items), and assert:
///
///   * selecting a variety + cross-section keeps that selection active across
///     the whole grid (Requirement 5.3) — the grid renders for every length;
///   * entering 3 bunches for the reaper shows the "30 pcs" piece-equivalent
///     and the correct line CFT (2.5000 CFT) via the shared engine
///     (Requirements 5.4, 5.5; Req 21.5);
///   * committing a reaper entry records it through the receiving service (the
///     pending balance moves by 30 pieces, verified by a DB read);
///   * a plank cross-section is entered in pieces (Requirement 5.5).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/presentation/settings/business_profile_providers.dart';
import 'package:wood_cft/presentation/stock/receiving_screen.dart';

/// The seeded catalog ids a test needs to drive and assert the grid.
class _Seed {
  const _Seed({
    required this.reaperVarietyId,
    required this.reaperCrossSectionId,
    required this.plankVarietyId,
    required this.plankCrossSectionId,
  });

  final int reaperVarietyId;
  final int reaperCrossSectionId;
  final int plankVarietyId;
  final int plankCrossSectionId;
}

/// Seeds a reaper (Mahogany, 2×1) and a plank (Kalani, 3×1), each with a stock
/// item at every length 2–9 ft.
Future<_Seed> _seedCatalog(AppDatabase db) async {
  final reaperVarietyId = await db.into(db.woodVarieties).insert(
        WoodVarietiesCompanion.insert(
          name: 'Mahogany',
          createdAt: DateTime.utc(2024, 1, 1),
        ),
      );
  final plankVarietyId = await db.into(db.woodVarieties).insert(
        WoodVarietiesCompanion.insert(
          name: 'Kalani',
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
  final plankCrossSectionId = await db.into(db.crossSections).insert(
        CrossSectionsCompanion.insert(
          widthIn: 3,
          thicknessIn: 1,
          category: CategoryKind.plank,
          bunchSize: 1,
        ),
      );
  for (var lengthFt = 2; lengthFt <= 9; lengthFt++) {
    await db.into(db.stockItems).insert(
          StockItemsCompanion.insert(
            varietyId: reaperVarietyId,
            crossSectionId: reaperCrossSectionId,
            lengthFt: lengthFt,
          ),
        );
    await db.into(db.stockItems).insert(
          StockItemsCompanion.insert(
            varietyId: plankVarietyId,
            crossSectionId: plankCrossSectionId,
            lengthFt: lengthFt,
          ),
        );
  }
  return _Seed(
    reaperVarietyId: reaperVarietyId,
    reaperCrossSectionId: reaperCrossSectionId,
    plankVarietyId: plankVarietyId,
    plankCrossSectionId: plankCrossSectionId,
  );
}

Future<int> _pendingPieces(
  AppDatabase db, {
  required int crossSectionId,
  required int lengthFt,
}) async {
  final row = await (db.select(db.stockItems)
        ..where((s) => s.crossSectionId.equals(crossSectionId))
        ..where((s) => s.lengthFt.equals(lengthFt)))
      .getSingle();
  return row.pendingBalancePieces;
}

void main() {
  late AppDatabase db;
  late _Seed seed;

  setUp(() async {
    db = openInMemoryDatabase();
    seed = await _seedCatalog(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const CupertinoApp(home: ReceivingScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'selecting a variety + reaper cross-section keeps the selection active '
      'across the full 2–9 ft grid', (tester) async {
    await pumpScreen(tester);

    // Before any selection, the grid is not shown — only the hint.
    expect(find.byKey(const Key('receiving_grid_hint')), findsOneWidget);
    expect(find.byKey(const Key('receiving_grid')), findsNothing);

    await tester
        .tap(find.byKey(Key('variety_choice_${seed.reaperVarietyId}')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('cross_section_choice_${seed.reaperCrossSectionId}')),
    );
    await tester.pumpAndSettle();

    // The selection drives the grid, and the same selection is active for
    // every length row 2–9 ft (Req 5.3).
    expect(find.byKey(const Key('receiving_grid')), findsOneWidget);
    for (var lengthFt = 2; lengthFt <= 9; lengthFt++) {
      expect(find.byKey(Key('length_row_$lengthFt')), findsOneWidget);
      expect(find.byKey(Key('qty_stepper_$lengthFt')), findsOneWidget);
    }
  });

  /// Increments the stepper in the row for [lengthFt] by [times] taps.
  Future<void> incrementRow(
    WidgetTester tester,
    int lengthFt,
    int times,
  ) async {
    final inc = find.descendant(
      of: find.byKey(Key('qty_stepper_$lengthFt')),
      matching: find.byKey(const Key('quantity_stepper_increment')),
    );
    for (var i = 0; i < times; i++) {
      await tester.tap(inc);
      await tester.pump();
    }
  }

  testWidgets(
      'entering 3 bunches for a reaper @6 ft shows 30 pcs piece-equivalent '
      'and 2.5000 CFT', (tester) async {
    await pumpScreen(tester);

    await tester
        .tap(find.byKey(Key('variety_choice_${seed.reaperVarietyId}')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('cross_section_choice_${seed.reaperCrossSectionId}')),
    );
    await tester.pumpAndSettle();

    await incrementRow(tester, 6, 3);

    final readout = tester.widget<Text>(find.byKey(const Key('readout_6')));
    expect(readout.data, contains('30 pcs'));
    // 2×1×6/144 = 1/12 per piece; 30 pcs → 2.5 CFT (Req 21.5).
    expect(readout.data, contains('2.5000 CFT'));
  });

  testWidgets('committing a reaper entry records it (pending +30 pcs)',
      (tester) async {
    await pumpScreen(tester);

    await tester
        .tap(find.byKey(Key('variety_choice_${seed.reaperVarietyId}')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('cross_section_choice_${seed.reaperCrossSectionId}')),
    );
    await tester.pumpAndSettle();

    expect(
      await _pendingPieces(
        db,
        crossSectionId: seed.reaperCrossSectionId,
        lengthFt: 6,
      ),
      0,
    );

    await incrementRow(tester, 6, 3);
    await tester.tap(find.byKey(const Key('commit_6')));
    await tester.pumpAndSettle();

    // The entry committed through ReceivingService → pending balance +30.
    expect(
      await _pendingPieces(
        db,
        crossSectionId: seed.reaperCrossSectionId,
        lengthFt: 6,
      ),
      30,
    );
    final feedback =
        tester.widget<Text>(find.byKey(const Key('receiving_feedback')));
    expect(feedback.data, contains('30 pcs'));
    expect(feedback.data, contains('pending'));
  });

  testWidgets('a plank cross-section is entered in pieces (no bunch label)',
      (tester) async {
    await pumpScreen(tester);

    await tester
        .tap(find.byKey(Key('variety_choice_${seed.plankVarietyId}')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('cross_section_choice_${seed.plankCrossSectionId}')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('receiving_grid_subtitle')), findsOneWidget);
    final subtitle = tester
        .widget<Text>(find.byKey(const Key('receiving_grid_subtitle')));
    expect(subtitle.data, contains('enter pieces'));

    // 3 pieces of a 3×1 @6 ft plank → 3×1×6/144 = 1/8 per piece; 3 pcs → 0.375.
    await incrementRow(tester, 6, 3);
    final readout = tester.widget<Text>(find.byKey(const Key('readout_6')));
    // Pieces input shows no bunch piece-equivalent prefix.
    expect(readout.data, isNot(contains('pcs ·')));
    expect(readout.data, contains('0.3750 CFT'));

    await tester.tap(find.byKey(const Key('commit_6')));
    await tester.pumpAndSettle();
    expect(
      await _pendingPieces(
        db,
        crossSectionId: seed.plankCrossSectionId,
        lengthFt: 6,
      ),
      3,
    );
  });
}
