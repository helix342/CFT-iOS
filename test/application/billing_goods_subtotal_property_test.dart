// Property-based test for the line-amount / goods-subtotal portion of
// Property 14 (task 10.1).
//
// Property 14 - Line amount is exact before half-up rounding, and goods
// subtotal sums rounded lines (design.md -> Correctness Properties;
// Requirements 9.1, 9.2, 9.3):
//
//   "For all lines, the pre-rounding line amount equals the exact product
//    exact_CFT × rate; each line amount is then rounded half-up to paise; and
//    the goods subtotal equals the sum of the independently rounded line
//    amounts."
//
// The test drives `BillingService.computeGoods` with random finite lists of
// priced lines. Each line's exact CFT is produced by the real engine
// (`CalculationService.lineCftFor` over random reaper/plank cross-sections,
// catalog lengths 2..9 ft, and whole quantities) and priced at a random exact
// ₹/CFT rate, so the property speaks to the values billing actually computes.
//
// For every generated list it asserts, over >= 100 iterations:
//   1. Per-line exactness: each line's stored exact pre-rounding amount equals
//      an independently computed `allocatedCft.value × rate` (Req 9.1).
//   2. Half-up rounding: each rounded line amount equals an independent
//      half-up-to-paise rounding of that exact rupee value (Req 9.2).
//   3. Subtotal = sum of rounded lines: the goods subtotal equals the exact
//      integer-paise sum of the independently rounded per-line amounts (Req
//      9.3) — NOT a single rounding of the exact sum.
//
// PBT framework: `package:glados`. `ExploreConfig(numRuns:, random:)` fixes the
// iteration count (>= 100) and seeds a deterministic `Random`, so any
// counterexample reproduces exactly. Glados re-exports `package:test`.
//
// Pure-Dart test: imports only the domain + application layers, `package:glados`,
// and `package:rational`. No Flutter widgets, no IO.

import 'package:glados/glados.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/money.dart';

/// The shared engine and the service under test.
const CalculationService _calc = CalculationService();
const BillingService _billing = BillingService(_calc);

/// Deterministic exploration config giving the property >= 100 iterations from
/// a fixed seed (so a failure reproduces exactly).
final ExploreConfig _explore =
    ExploreConfig(numRuns: 200, random: Random(20240610));

/// A randomly generated priced line: a cross-section, a catalog length, a whole
/// quantity, and a whole ₹/CFT rate. Its exact CFT comes from the real engine.
class _Line {
  const _Line(this.widthIn, this.thicknessIn, this.isReaper, this.lengthFt,
      this.quantity, this.rateRupees);

  final int widthIn;
  final int thicknessIn;
  final bool isReaper;
  final int lengthFt;
  final int quantity;
  final int rateRupees;

  CrossSection get crossSection => CrossSection(
        id: 1,
        widthIn: widthIn,
        thicknessIn: thicknessIn,
        category: isReaper ? WoodCategory.reaper : WoodCategory.plank,
      );

  Rational get rate => Rational.fromInt(rateRupees);

  GoodsLineInput get input => GoodsLineInput(
        stockItemId: 1,
        varietyId: 1,
        crossSectionId: 1,
        lengthFt: lengthFt,
        allocatedCft: _calc.lineCftFor(crossSection, lengthFt, quantity),
        rate: rate,
      );

  @override
  String toString() => '_Line(w: $widthIn, t: $thicknessIn, '
      'cat: ${isReaper ? 'reaper' : 'plank'}, l: $lengthFt, q: $quantity, '
      'rate: $rateRupees)';
}

/// Generator for one valid priced line, constrained to the real input space:
/// width 1..12 in, thickness 1..6 in, length 2..9 ft (Requirement 1.10),
/// quantity 1..300 pieces, rate 1..5000 ₹/CFT.
final Generator<_Line> _lineGen = any.combine6(
  any.intInRange(1, 13), // widthIn 1..12
  any.intInRange(1, 7), // thicknessIn 1..6
  any.bool, // reaper vs plank
  any.intInRange(2, 10), // lengthFt 2..9
  any.intInRange(1, 301), // quantity 1..300
  any.intInRange(1, 5001), // rate 1..5000 ₹/CFT
  _Line.new,
);

/// Generator for a finite list of 0..20 priced lines (includes the empty list,
/// whose subtotal must be exactly zero).
final Generator<List<_Line>> _linesGen =
    any.listWithLengthInRange(0, 21, _lineGen);

/// Independent half-up-to-paise rounding of an exact rupee amount, mirroring
/// `Money.fromExactRupees` without reusing it, so the test is a genuine oracle.
BigInt _expectedPaiseHalfUp(Rational exactRupees) {
  final paiseExact = exactRupees * Rational.fromInt(100);
  final floor = paiseExact.floor();
  final fraction = paiseExact - Rational(floor);
  final half = Rational(BigInt.one, BigInt.from(2));
  return fraction >= half ? floor + BigInt.one : floor;
}

void main() {
  group('Goods line amount + subtotal (Property 14, glados)', () {
    Glados<List<_Line>>(_linesGen, _explore).test(
      'Feature: wood-cft-app, Property 14: Line amount is exact before half-up '
      'rounding, and goods subtotal sums rounded lines - each line amount is '
      'the exact CFT×rate product rounded half-up to paise, and the goods '
      'subtotal equals the sum of the independently rounded line amounts '
      '(Requirements 9.1, 9.2, 9.3)',
      (List<_Line> lines) {
        final inputs = [for (final line in lines) line.input];
        final bill = _billing.computeGoods(inputs);

        expect(bill.lines, hasLength(inputs.length));

        // Build the expected subtotal as an independent integer-paise sum of
        // per-line half-up roundings of the exact rupee product.
        var expectedSubtotalPaise = BigInt.zero;
        for (var i = 0; i < inputs.length; i++) {
          final input = inputs[i];
          final computed = bill.lines[i];

          // (1) Per-line exactness: pre-rounding amount == exact CFT × rate.
          final expectedExact = input.allocatedCft.value * input.rate;
          expect(computed.exactAmountRupees, expectedExact,
              reason: 'line $i exact amount must equal allocatedCft × rate');

          // (2) Half-up rounding to paise, independently computed.
          final expectedPaise = _expectedPaiseHalfUp(expectedExact);
          expect(computed.amount, Money(expectedPaise),
              reason: 'line $i must be the half-up rounding of its exact value');

          expectedSubtotalPaise += expectedPaise;
        }

        // (3) Subtotal == sum of the independently rounded line amounts.
        expect(bill.goodsSubtotal, Money(expectedSubtotalPaise),
            reason: 'goods subtotal must equal the sum of rounded line amounts');

        if (inputs.isEmpty) {
          expect(bill.goodsSubtotal, Money.zero);
        }
      },
    );
  });
}
