// Property-based test for the single-line literal tax (task 10.2).
//
// Property 15 - Single-line literal tax on the taxable subtotal (design.md ->
// Correctness Properties; Requirements 10.1, 10.2, 10.3, 10.5):
//
//   "For all taxable subtotals and tax modes in {No GST, 9%, 18%}, the computed
//    tax equals taxable_subtotal × literal_rate (zero for No GST), presented as
//    exactly one tax line (never split into CGST/SGST)."
//
// The test drives `BillingService.taxOnSubtotal` with random taxable subtotals
// (random integer paise) across all three tax modes. For every generated
// (subtotal, mode) it asserts, over >= 100 iterations:
//
//   1. Literal rate: the tax equals an independently computed half-up-to-paise
//      rounding of `subtotal × mode.rate`, where the rate is the ONE literal
//      total rate 0 / 9/100 / 18/100 (Requirements 10.1, 10.3).
//   2. No GST → zero: for TaxMode.noGst the tax is exactly Money.zero whatever
//      the subtotal (Requirement 10.5).
//   3. Single line, never split: the service exposes exactly one tax figure.
//      Reconstructing a CGST/SGST split from the half rate and summing the two
//      independently rounded halves can differ from the one-line literal tax,
//      so the single literal line is NOT equal to a two-line split in general
//      (Requirement 10.2) — the model is structurally one line.
//
// PBT framework: `package:glados`. `ExploreConfig(numRuns:, random:)` fixes the
// iteration count (>= 100) and seeds a deterministic `Random`, so any
// counterexample reproduces exactly. Glados re-exports `package:test`.
//
// Pure-Dart test: imports only the application + domain layers,
// `package:glados`, and `package:rational`. No Flutter widgets, no IO.

import 'package:glados/glados.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/domain/money.dart';

/// The service under test (goods billing + the single literal tax line).
const BillingService _billing = BillingService();

/// Deterministic exploration config giving the property >= 100 iterations from
/// a fixed seed (so a failure reproduces exactly).
final ExploreConfig _explore =
    ExploreConfig(numRuns: 200, random: Random(20240612));

/// The three literal tax modes, as the property quantifies over
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

void main() {
  group('Single-line literal tax (Property 15, glados)', () {
    // Taxable subtotal in paise: 0 up to ₹10,00,00,000 (a crore), covering
    // zero and large bills. The mode index selects No GST / 9% / 18%.
    Glados2<int, int>(
      any.intInRange(0, 100000000001), // subtotal paise: 0 .. 10^11
      any.intInRange(0, 3), // mode index 0..2
      _explore,
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

        // (2) No GST → exactly zero tax, whatever the subtotal (Req 10.5).
        if (mode == TaxMode.noGst) {
          expect(tax, Money.zero,
              reason: 'No GST must yield zero tax for subtotal $subtotalPaise');
          expect(mode.rate, Rational.zero);
          return;
        }

        // (1) Literal rate: tax == half-up(subtotal × literal_rate) (Req 10.1,
        // 10.3), computed from an independent oracle.
        final subtotalRupees =
            Rational(BigInt.from(subtotalPaise), BigInt.from(100));
        final expectedPaise =
            _expectedPaiseHalfUp(subtotalRupees * mode.rate);
        expect(tax, Money(expectedPaise),
            reason: 'tax must equal half-up(subtotal × ${mode.rate})');

        // (3) Single line, never split into CGST + SGST (Req 10.2): a
        // half-rate two-line split, each half independently rounded to paise,
        // can differ from the one-line literal tax. Where it differs, the
        // service's single-line value proves it is NOT a CGST/SGST split.
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
