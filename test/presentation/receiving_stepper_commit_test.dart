/// Receiving stepper-commit widget test (app-ux-revamp task 4.1).
///
/// Verifies that adjusting a length's quantity with the shared +/- stepper and
/// then activating the icon-only "Add to inventory" action records exactly the
/// stepped quantity through the receiving service (Requirement 2.5), and that
/// the add action is disabled while the stepper reads zero (Requirement 2.2).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/presentation/settings/business_profile_providers.dart';
import 'package:wood_cft/presentation/stock/receiving_screen.dart';

void main() {
  late AppDatabase db;
  late int varietyId;
  late int reaperId;

  setUp(() async {
    db = openInMemoryDatabase();
    varietyId = await db.into(db.woodVarieties).insert(
          WoodVarietiesCompanion.insert(
            name: 'Teak',
            createdAt: DateTime.utc(2024, 1, 1),
          ),
        );
    reaperId = await db.into(db.crossSections).insert(
          CrossSectionsCompanion.insert(
            widthIn: 2,
            thicknessIn: 1,
            category: CategoryKind.reaper,
            bunchSize: 10,
          ),
        );
    for (var lengthFt = 2; lengthFt <= 9; lengthFt++) {
      await db.into(db.stockItems).insert(
            StockItemsCompanion.insert(
              varietyId: varietyId,
              crossSectionId: reaperId,
              lengthFt: lengthFt,
            ),
          );
    }
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpAndSelect(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const CupertinoApp(home: ReceivingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('variety_choice_$varietyId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('cross_section_choice_$reaperId')));
    await tester.pumpAndSettle();
  }

  Future<int> pendingAt(int lengthFt) async {
    final row = await (db.select(db.stockItems)
          ..where((s) => s.crossSectionId.equals(reaperId))
          ..where((s) => s.lengthFt.equals(lengthFt)))
        .getSingle();
    return row.pendingBalancePieces;
  }

  testWidgets('stepping up then activating the add icon records the entry',
      (tester) async {
    await pumpAndSelect(tester);

    final inc = find.descendant(
      of: find.byKey(const Key('qty_stepper_5')),
      matching: find.byKey(const Key('quantity_stepper_increment')),
    );
    // Step to 4 bunches (= 40 pieces for a reaper).
    for (var i = 0; i < 4; i++) {
      await tester.tap(inc);
      await tester.pump();
    }

    expect(await pendingAt(5), 0);

    await tester.tap(find.byKey(const Key('commit_5')));
    await tester.pumpAndSettle();

    expect(await pendingAt(5), 40);
    // The stepper resets to zero after a successful commit.
    expect(
      find.descendant(
        of: find.byKey(const Key('qty_stepper_5')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the add icon is disabled while the stepper reads zero',
      (tester) async {
    await pumpAndSelect(tester);

    final button = tester.widget<CupertinoButton>(
      find.descendant(
        of: find.byKey(const Key('commit_7')),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(await pendingAt(7), 0);
  });
}
