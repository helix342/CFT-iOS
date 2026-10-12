// Property-based tests for the billing engine's goods subtotal and single-line
// tax (task 10.4).
//
// Task 10.4 names TWO properties; per the one-property-per-test rule this file
// carries ONE `Glados` test per property, each tagged separately:
//
//   * Property 14 — Line amount is exact before half-up rounding, and the goods
//     subtotal sums the independently rounded line amounts (Requirements 9.1,
//     9.2, 9.3).
//   * Property 15 — Single-line literal tax on the taxable subtotal: tax =
//     taxable_subtotal × literal_rate for the chosen TaxMode, presented as
//     exactly ONE tax line (never a CGST/SGST split; No GST → zero)
//     (Requirements 10.1, 10.2, 10.3, 10.5).
//
// Both properties quantify over the values billing actually computes. The exact
// per-line CFT comes from the real shared engine (`CalculationService.lineCftFor`
// over random reaper/plank cross-sections, catalog lengths 2..9 ft, and whole
// quantities) priced at a random exact ₹/CFT rate, and the tax runs over random
// taxable subtotals across every TaxMode.
//
// Each property is checked with an INDEPENDENT half-up-to-paise oracle that
// mirrors `Money.fromExactRupees` without reusing it, so the tests genuinely
// re-derive the expected figure rather than echoing the implementation.
//
// PBT framework: `package:glados`. `ExploreConfig(numRuns:, random:)` fixes the
// iteration count (150–200, >= 100) and seeds a deterministic `Random`, so any
// counterexample reproduces exactly. Glados re-exports `package:test`.
//
// Pure-Dart test: imports only the domain + application layers, `package:glados`,
// and `package:rational`. No Flutter widgets, no IO — runs under `flutter test`
// on Windows.

import 'package:glados/glados.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/money.dart';

/// The shared engine and the service under test.
const CalculationService _calc = CalculationService();
const BillingService _billing = BillingService(_calc);

/// Deterministic exploration configs (one per property) giving each property
/// 180 iterations (>= 100) from a fixed seed, so a failure reproduces exactly.
final ExploreConfig _exploreGoods =
    ExploreConfig(numRuns: 180, random: Random(20240701));
final ExploreConfig _exploreTax =
    ExploreConfig(numRuns: 180, random: Random(20240702));

/// The three literal tax modes the tax property quantifies over
/// {No GST, 9%, 18%}.
const List<TaxMode> _modes = TaxMode.values;

/// Independent half-up-to-paise rounding of an exact rupee amount, mirroring
/// `Money.fromExactRupees` without reusing it, so the test is a genuine oracle.
BigInt _expectedPaiseHalfUp(Rational exactRupees) {
  final paiseExact = exactRupees * Rational.fromInt(100);
  final floor = paiseExact.floor();
  final fraction = paiseExact - Rational(floor);
  final half = Rational(BigInt.one, BigInt.from(2));
  return fraction >= half ? floor + BigInt.one : floor;
}

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

void main() {
  group('Billing goods subtotal (Property 14, glados)', () {
    Glados<List<_Line>>(_linesGen, _exploreGoods).test(
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

          // (a) Per-line exactness: pre-rounding amount == exact CFT × rate.
          final expectedExact = input.allocatedCft.value * input.rate;
          expect(computed.exactAmountRupees, expectedExact,
              reason: 'line $i exact amount must equal allocatedCft × rate');

          // (a) Half-up rounding to paise, independently computed.
          final expectedPaise = _expectedPaiseHalfUp(expectedExact);
          expect(computed.amount, Money(expectedPaise),
              reason: 'line $i must be the half-up rounding of its exact value');

          expectedSubtotalPaise += expectedPaise;
        }

        // (a) Subtotal == order-independent sum of the independently rounded
        // line amounts (addition over paise is commutative/associative).
        expect(bill.goodsSubtotal, Money(expectedSubtotalPaise),
            reason: 'goods subtotal must equal the sum of rounded line amounts');

        if (inputs.isEmpty) {
          expect(bill.goodsSubtotal, Money.zero);
        }
      },
    );
  });

  group('Billing single-line literal tax (Property 15, glados)', () {
    // Taxable subtotal in paise: 0 up to ₹10,00,00,000 (a crore), covering zero
    // and large bills. The mode index selects No GST / 9% / 18%.
    Glados2<int, int>(
      any.intInRange(0, 100000000001), // subtotal paise: 0 .. 10^11
      any.intInRange(0, 3), // mode index 0..2
      _exploreTax,
    ).test(
      'Feature: wood-cft-app, Property 15: Single-line literal tax on the '
      'taxable subtotal - for all taxable subtotals and modes in '
      '{No GST, 9%, 18%}, tax = taxable_subtotal × literal_rate (zero for '
      'No GST), as exactly one tax line never split into CGST/SGST '
      '(Requirements 10.1, 10.2, 10.3, 10.5)',
      (int subtotalPaise, int modeIndex) {
        final subtotal = Money.fromPaise(subtotalPaise);
        final mode = _modes[modeIndex];

        final tax = _billing.taxOnSubtotal(subtotal, mode);

        // (b) No GST → exactly zero tax, whatever the subtotal (Req 10.5).
        if (mode == TaxMode.noGst) {
          expect(tax, Money.zero,
              reason: 'No GST must yield zero tax for subtotal $subtotalPaise');
          expect(mode.rate, Rational.zero);
          return;
        }

        // (b) Literal rate: tax == half-up(subtotal × literal_rate) (Req 10.1,
        // 10.3), computed from an independent oracle.
        final subtotalRupees =
            Rational(BigInt.from(subtotalPaise), BigInt.from(100));
        final expectedPaise =
            _expectedPaiseHalfUp(subtotalRupees * mode.rate);
        expect(tax, Money(expectedPaise),
            reason: 'tax must equal half-up(subtotal × ${mode.rate})');

        // (b) Single line, never split into CGST + SGST (Req 10.2): a half-rate
        // two-line split, each half independently rounded to paise, can differ
        // from the one-line literal tax. Where it differs, the service's single
        // literal value proves it is NOT a CGST/SGST split.
        final halfRate = mode.rate / Rational.fromInt(2);
        final halfLine = _expectedPaiseHalfUp(subtotalRupees * halfRate);
        final splitSum = halfLine + halfLine;
        if (splitSum != expectedPaise) {
          expect(tax, isNot(Money(splitSum)),
              reason: 'single literal line must not equal a CGST/SGST split');
        }
      },
    );
  });
}
