/// Widget tests for the Stock-tab inventory browser screen (task 6.2).
///
/// Boots [InventoryBrowserScreen] with the shared drift database overridden to
/// a seeded in-memory instance and asserts the browser contract:
///   * rows render available quantity AND available CFT, each with an explicit
///     unit label (Requirements 6.2, 6.5, 17.6) — reapers show bunches + the
///     piece-equivalent, planks show pieces;
///   * a pending item shows a non-color (text + icon) pending badge
///     (Requirement 19.8);
///   * the zero-stock toggle hides items whose CONFIRMED balance is zero and
///     shows them again when re-enabled (Requirement 6.4);
///   * an out-of-stock item carries a non-color shortage indicator
///     (Requirement 17.5);
///   * filtered totals render with explicit unit labels (Requirement 6.3).
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/presentation/stock/inventory_browser_screen.dart';
import 'package:wood_cft/presentation/stock/inventory_providers.dart';

Future<int> _seedVariety(AppDatabase db, String name) =>
    db.into(db.woodVarieties).insert(
          WoodVarietiesCompanion.insert(
            name: name,
            createdAt: DateTime.utc(2024, 1, 1),
          ),
        );

Future<int> _seedCrossSection(
  AppDatabase db, {
  required int widthIn,
  required int thicknessIn,
  required CategoryKind category,
}) =>
    db.into(db.crossSections).insert(
          CrossSectionsCompanion.insert(
            widthIn: widthIn,
            thicknessIn: thicknessIn,
            category: category,
            bunchSize: category == CategoryKind.reaper ? 10 : 1,
          ),
        );

Future<int> _seedStock(
  AppDatabase db, {
  required int varietyId,
  required int crossSectionId,
  required int lengthFt,
  required int confirmed,
  required int pending,
}) =>
    db.into(db.stockItems).insert(
          StockItemsCompanion.insert(
            varietyId: varietyId,
            crossSectionId: crossSectionId,
            lengthFt: lengthFt,
            confirmedBalancePieces: Value(confirmed),
            pendingBalancePieces: Value(pending),
          ),
        );

void main() {
  late AppDatabase db;

  // Seeded ids, filled in setUp so individual tests can reference them.
  late int mahoganyId;
  late int reaper2x1Id;
  late int plank3x1Id;

  setUp(() async {
    db = openInMemoryDatabase();
    mahoganyId = await _seedVariety(db, 'Mahogany');
    reaper2x1Id = await _seedCrossSection(
      db,
      widthIn: 2,
      thicknessIn: 1,
      category: CategoryKind.reaper,
    );
    plank3x1Id = await _seedCrossSection(
      db,
      widthIn: 3,
      thicknessIn: 1,
      category: CategoryKind.plank,
    );

    // Reaper 2×1 @ 6 ft: 30 confirmed pieces (3 bunches), 10 pending.
    // CFT = 2·1·6/144 · 30 = 2.5000.
    await _seedStock(
      db,
      varietyId: mahoganyId,
      crossSectionId: reaper2x1Id,
      lengthFt: 6,
      confirmed: 30,
      pending: 10,
    );
    // Plank 3×1 @ 8 ft: 12 confirmed pieces. CFT = 3·1·8/144 · 12 = 2.0000.
    await _seedStock(
      db,
      varietyId: mahoganyId,
      crossSectionId: plank3x1Id,
      lengthFt: 8,
      confirmed: 12,
      pending: 0,
    );
    // Plank 3×1 @ 4 ft: 0 confirmed pieces -> zero-stock / out-of-stock.
    await _seedStock(
      db,
      varietyId: mahoganyId,
      crossSectionId: plank3x1Id,
      lengthFt: 4,
      confirmed: 0,
      pending: 0,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpBrowser(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const CupertinoApp(home: InventoryBrowserScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'rows render quantity and CFT with explicit unit labels '
    '(reaper bunches + piece-equivalent, plank pieces)',
    (tester) async {
      await pumpBrowser(tester);

      // Reaper 30 pcs shown as whole bunches with the piece-equivalent.
      expect(find.text('3 bunches (30 pcs)'), findsOneWidget);
      // Plank shown in pieces.
      expect(find.text('12 pcs'), findsOneWidget);

      // CFT values carry an explicit "CFT" unit label, never a bare number.
      expect(find.text('2.5000 CFT'), findsOneWidget);
      expect(find.text('2.0000 CFT'), findsOneWidget);

      // Every quantity/CFT cell uses a labelled unit (no bare numbers).
      final qtyFinder = find.byKey(const Key('inventory_row_quantity'));
      expect(qtyFinder, findsWidgets);
      for (final text in tester.widgetList<Text>(qtyFinder)) {
        final data = text.data ?? '';
        expect(
          data.contains('pcs') || data.contains('bunch'),
          isTrue,
          reason: 'quantity "$data" must carry an explicit unit label',
        );
      }
      final cftFinder = find.byKey(const Key('inventory_row_cft'));
      for (final text in tester.widgetList<Text>(cftFinder)) {
        expect((text.data ?? '').contains('CFT'), isTrue);
      }
    },
  );

  testWidgets('a pending item shows a non-color (text + icon) pending badge', (
    tester,
  ) async {
    await pumpBrowser(tester);

    final pendingBadge = find.byKey(const Key('inventory_pending_badge'));
    expect(pendingBadge, findsOneWidget);

    // The pending cue is conveyed by text (and an icon), not color alone.
    expect(
      find.descendant(of: pendingBadge, matching: find.text('Pending 10 pcs')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: pendingBadge, matching: find.byType(Icon)),
      findsOneWidget,
    );
  });

  testWidgets('an out-of-stock item carries a non-color shortage indicator', (
    tester,
  ) async {
    await pumpBrowser(tester);

    final shortage = find.byKey(const Key('inventory_shortage_indicator'));
    expect(shortage, findsOneWidget);
    expect(
      find.descendant(of: shortage, matching: find.text('Out of stock')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: shortage, matching: find.byType(Icon)),
      findsOneWidget,
    );
  });

  testWidgets('zero-stock toggle hides and re-shows zero-confirmed items', (
    tester,
  ) async {
    await pumpBrowser(tester);

    // Initially everything is shown: the zero-stock plank's shortage cue is
    // present.
    expect(
      find.byKey(const Key('inventory_shortage_indicator')),
      findsOneWidget,
    );

    // Turning the toggle OFF hides zero-confirmed items.
    await tester.tap(find.byKey(const Key('inventory_zero_stock_toggle')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('inventory_shortage_indicator')),
      findsNothing,
    );
    // The two in-stock items remain.
    expect(find.text('3 bunches (30 pcs)'), findsOneWidget);
    expect(find.text('12 pcs'), findsOneWidget);

    // Turning it back ON re-shows the zero-stock item.
    await tester.tap(find.byKey(const Key('inventory_zero_stock_toggle')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('inventory_shortage_indicator')),
      findsOneWidget,
    );
  });

  testWidgets('filtered totals render with explicit unit labels', (
    tester,
  ) async {
    await pumpBrowser(tester);

    final totals = find.byKey(const Key('inventory_totals'));
    expect(totals, findsOneWidget);

    // Total available pieces: 30 + 12 + 0 = 42 pcs.
    expect(
      find.descendant(of: totals, matching: find.text('42 pcs')),
      findsOneWidget,
    );
    // Total available CFT: 2.5000 + 2.0000 = 4.5000 CFT.
    expect(
      find.descendant(of: totals, matching: find.text('4.5000 CFT')),
      findsOneWidget,
    );
  });
}
