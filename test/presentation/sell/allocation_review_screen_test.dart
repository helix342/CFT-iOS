/// Widget tests for the Sell-tab allocation review / picking-list screen
/// (task 9.5).
///
/// These boot [AllocationReviewScreen] with the drift database overridden to an
/// in-memory instance seeded with a 2×1 reaper SKU at 6 ft (one bunch of 10
/// pieces = 5/6 CFT ≈ 0.8333), stage a structured request on the shared
/// [draftOrderRequestsProvider], and assert the picking list renders the
/// requested-vs-allocated CFT, the per-line picking rows (stock item / length /
/// units / pieces / CFT), and — crucially — a clearly labelled **PARTIAL** with
/// its shortage when the confirmed stock cannot fully meet the demand
/// (Requirements 8.3, 8.4).
///
/// The hosted DB is never touched; only the in-memory drift database and the
/// in-memory draft/allocation providers are exercised, so these run under
/// `flutter test` on Windows with no device.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/domain/order_request.dart';
import 'package:wood_cft/presentation/sell/allocation_review_providers.dart';
import 'package:wood_cft/presentation/sell/allocation_review_screen.dart';
import 'package:wood_cft/presentation/sell/sell_providers.dart';

/// The seeded ids a test needs to stage a request and assert the picking list.
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

  Future<_Seed> setUpWith({required int confirmed}) async {
    db = openInMemoryDatabase();
    final seed = await _seed(db, confirmed: confirmed);
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    return seed;
  }

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CupertinoApp(home: AllocationReviewScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty draft shows the nothing-to-review state', (tester) async {
    await setUpWith(confirmed: 50);
    await pumpScreen(tester);
    expect(find.byKey(const Key('allocation_review_empty')), findsOneWidget);
    expect(find.byKey(const Key('allocation_review_list')), findsNothing);
  });

  testWidgets(
      'full allocation: a covered exact-quantity reaper line shows the picking '
      'row and the met-or-exceeded status, with no PARTIAL (Req 8.3)',
      (tester) async {
    // 50 confirmed pieces = 5 bunches available; demand 3 bunches (30 pcs).
    final seed = await setUpWith(confirmed: 50);
    container.read(draftOrderRequestsProvider.notifier).add(
          ExactQtyRequest(
            varietyId: seed.varietyId,
            crossSectionId: seed.reaperCrossSectionId,
            lengthFt: 6,
            quantityUnits: 3,
          ),
        );

    await pumpScreen(tester);

    // Order-level banner is the "complete" (met-or-exceeded) state.
    expect(find.byKey(const Key('allocation_order_status')), findsOneWidget);
    expect(find.text('All lines met or exceeded'), findsOneWidget);

    // No partial anywhere.
    expect(find.byKey(const Key('allocation_partial_badge')), findsNothing);
    expect(find.byKey(const Key('allocation_line_0_shortage')), findsNothing);

    // The picking row: 3 bunches (30 pcs) of the seeded stock item, 2.5000 CFT
    // (30 pieces × 1/12 CFT each at 2×1×6/144).
    expect(
      find.byKey(const Key('allocation_pick_0_0_qty')),
      findsOneWidget,
    );
    expect(find.text('3 bunches (30 pcs)'), findsOneWidget);
    expect(find.text('Item #${seed.stockItemId}  ·  6 ft'), findsOneWidget);
    expect(
      find.byKey(const Key('allocation_line_0_allocated_cft')),
      findsOneWidget,
    );
    expect(find.text('2.5000 CFT'), findsWidgets);

    // Totals footer sums the picking rows.
    expect(find.byKey(const Key('allocation_total_pieces')), findsOneWidget);
    expect(find.text('30 pcs'), findsWidgets);
  });

  testWidgets(
      'partial allocation: an under-stocked exact-quantity reaper line is '
      'clearly labelled PARTIAL with its shortage, never fulfilled (Req 8.4)',
      (tester) async {
    // Only 30 confirmed pieces = 3 bunches; demand 6 bunches (60 pcs).
    final seed = await setUpWith(confirmed: 30);
    container.read(draftOrderRequestsProvider.notifier).add(
          ExactQtyRequest(
            varietyId: seed.varietyId,
            crossSectionId: seed.reaperCrossSectionId,
            lengthFt: 6,
            quantityUnits: 6,
          ),
        );

    await pumpScreen(tester);

    // Order-level banner says PARTIAL (icon + text), never "fulfilled".
    expect(
      find.text('PARTIAL — some lines could not be fully met'),
      findsOneWidget,
    );
    expect(find.text('All lines met or exceeded'), findsNothing);

    // The line carries a PARTIAL badge and a shortage sentence: 3 bunches short
    // (30 pcs) — only 3 of the 6 requested bunches fit.
    expect(find.byKey(const Key('allocation_partial_badge')), findsOneWidget);
    final shortage = find.byKey(const Key('allocation_line_0_shortage'));
    expect(shortage, findsOneWidget);
    expect(
      tester.widget<Text>(shortage).data,
      'PARTIAL — short 3 bunches (30 pcs)',
    );

    // What DID fit is still shown honestly: 3 bunches (30 pcs), 2.5000 CFT.
    expect(find.text('3 bunches (30 pcs)'), findsOneWidget);
    expect(find.text('2.5000 CFT'), findsWidgets);
  });
}
