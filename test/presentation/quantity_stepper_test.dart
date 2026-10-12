/// Widget tests for the shared [QuantityStepper] (app-ux-revamp task 3.1).
///
/// The stepper is a controlled widget, so these tests host it in a small
/// stateful harness that owns the value and feeds changes back in. They assert
/// (Requirements 2.2, 2.6, 3.4):
///
///   * incrementing and decrementing change the value by one;
///   * decrement clamps at the minimum (never negative / below `minValue`);
///   * tap-to-type parses a whole number and sets it;
///   * the digits-only field rejects non-whole / negative characters.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/presentation/common/quantity_stepper.dart';

/// A tiny harness that owns the stepper's value so the controlled widget can
/// be driven in tests.
class _StepperHarness extends StatefulWidget {
  const _StepperHarness({
    this.initial = 0,
    this.maxValue,
  });

  final int initial;
  final int? maxValue;

  @override
  State<_StepperHarness> createState() => _StepperHarnessState();
}

class _StepperHarnessState extends State<_StepperHarness> {
  late int _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      home: CupertinoPageScaffold(
        child: Center(
          child: QuantityStepper(
            value: _value,
            unitLabel: 'pcs',
            maxValue: widget.maxValue,
            onChanged: (v) => setState(() => _value = v),
          ),
        ),
      ),
    );
  }
}

void main() {
  group('QuantityStepper', () {
    testWidgets('increment raises the value by one', (tester) async {
      await tester.pumpWidget(const _StepperHarness(initial: 2));

      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('quantity_stepper_increment')));
      await tester.pump();
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('decrement lowers the value by one', (tester) async {
      await tester.pumpWidget(const _StepperHarness(initial: 2));

      await tester.tap(find.byKey(const Key('quantity_stepper_decrement')));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('decrement clamps at the minimum and never goes negative',
        (tester) async {
      await tester.pumpWidget(const _StepperHarness(initial: 0));

      // The decrement button is disabled at the floor, so tapping is a no-op.
      await tester.tap(find.byKey(const Key('quantity_stepper_decrement')));
      await tester.pump();
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('increment clamps at the maximum', (tester) async {
      await tester.pumpWidget(
        const _StepperHarness(initial: 5, maxValue: 5),
      );

      await tester.tap(find.byKey(const Key('quantity_stepper_increment')));
      await tester.pump();
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('tap-to-type sets an exact whole count', (tester) async {
      await tester.pumpWidget(const _StepperHarness(initial: 1));

      await tester.tap(find.byKey(const Key('quantity_stepper_value')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('quantity_stepper_direct_field')),
        '42',
      );
      await tester.tap(find.text('Set'));
      await tester.pumpAndSettle();

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('direct entry rejects non-digit characters', (tester) async {
      await tester.pumpWidget(const _StepperHarness(initial: 7));

      await tester.tap(find.byKey(const Key('quantity_stepper_value')));
      await tester.pumpAndSettle();

      // The digits-only formatter strips letters and the minus sign, so a
      // "-3abc" attempt yields "3".
      await tester.enterText(
        find.byKey(const Key('quantity_stepper_direct_field')),
        '-3abc',
      );
      await tester.tap(find.text('Set'));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
    });
  });
}
