/// Adjustable staged-order-lines widget test (app-ux-revamp task 5.1).
///
/// Hosts [StagedOrderLinesView] over a seeded staged line and asserts
/// (Requirements 3.3, 3.4, 3.5):
///
///   * each line shows its exact 4-dp CFT from the shared engine;
///   * incrementing the quantity recomputes the exact CFT and the running
///     total immediately;
///   * decrementing a single-unit line to zero removes it.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/presentation/orders/order_build_providers.dart';
import 'package:wood_cft/presentation/orders/staged_order_line.dart';
import 'package:wood_cft/presentation/orders/staged_order_lines_view.dart';

void main() {
  // A 2x1 reaper (bunch size 10). One bunch @6 ft = 10 pcs x (2*1*6/144) =
  // 10 x 1/12 = 10/12 = 0.8333 CFT. Two bunches = 1.6667 CFT.
  final reaper = CrossSection(
    id: 1,
    widthIn: 2,
    thicknessIn: 1,
    category: WoodCategory.reaper,
    bunchSize: 10,
  );

  StagedOrderLine lineOf(int units) => StagedOrderLine(
        varietyId: 1,
        varietyName: 'Teak',
        crossSection: reaper,
        lengthFt: 6,
        quantityUnits: units,
      );

  Future<ProviderContainer> pumpView(
    WidgetTester tester, {
    required List<StagedOrderLine> seed,
  }) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(stagedOrderLinesProvider.notifier).replaceAll(seed);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CupertinoApp(
          home: CupertinoPageScaffold(
            child: SingleChildScrollView(child: StagedOrderLinesView()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('each line shows exact CFT and a running total (Req 3.1, 3.5)',
      (tester) async {
    await pumpView(tester, seed: [lineOf(1)]);

    final cft = tester.widget<Text>(find.byKey(const Key('staged_line_cft_0')));
    expect(cft.data, contains('0.8333 CFT'));
    expect(find.text('0.8333 CFT'), findsOneWidget);
  });

  testWidgets('incrementing recomputes exact CFT immediately (Req 3.3)',
      (tester) async {
    await pumpView(tester, seed: [lineOf(1)]);

    final inc = find.descendant(
      of: find.byKey(const Key('staged_line_stepper_0')),
      matching: find.byKey(const Key('quantity_stepper_increment')),
    );
    await tester.tap(inc);
    await tester.pump();

    // Two bunches @6 ft = 1.6667 CFT.
    final cft = tester.widget<Text>(find.byKey(const Key('staged_line_cft_0')));
    expect(cft.data, contains('1.6667 CFT'));
    expect(cft.data, contains('2 bunches'));
    expect(find.text('1.6667 CFT'), findsOneWidget);
  });

  testWidgets('decrementing a single-unit line to zero removes it (Req 3.4)',
      (tester) async {
    final container = await pumpView(tester, seed: [lineOf(1)]);

    final dec = find.descendant(
      of: find.byKey(const Key('staged_line_stepper_0')),
      matching: find.byKey(const Key('quantity_stepper_decrement')),
    );
    await tester.tap(dec);
    await tester.pumpAndSettle();

    expect(container.read(stagedOrderLinesProvider), isEmpty);
    expect(find.byKey(const Key('staged_lines_empty')), findsOneWidget);
  });
}
