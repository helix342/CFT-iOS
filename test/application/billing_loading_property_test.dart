// Property-based tests for the loading charge and payable (task 10.3).
//
// These implement the design's Correctness Properties 16 and 17 (design.md ->
// Correctness Properties; Requirement 11) over `BillingService.computeTotals` /
// `computeLoading` and the `LoadingPolicy` tier function:
//
//   Property 16 - Loading is excluded from tax, added once after tax: for all
//     orders the taxable subtotal equals the goods subtotal (loading
//     excluded), exactly one loading charge is applied, and
//     payable = goods_subtotal + tax + loading; loading is applied even in
//     No-GST mode (Requirements 9.4, 10.4, 11.4, 11.5, 11.6).
//
//   Property 17 - Loading tier is a step function on exact CFT at 20: for all
//     orders the loading charge is ₹100 when the exact total sold CFT is below
//     20 and ₹150 at or above 20 (exactly 20 → ₹150), compared on the exact
//     CFT value and never on the display-rounded value (Requirements 11.1,
//     11.2, 11.3).
//
// PBT framework: `package:glados`. `ExploreConfig(numRuns:, random:)` fixes the
// iteration count (>= 100) from a seeded `Random`, so a counterexample
// reproduces exactly. Glados re-exports `package:test`.
//
// Pure-Dart test: imports only the application + domain layers,
// `package:glados`, and `package:rational`. No Flutter widgets, no IO.

import 'package:glados/glados.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/domain/cft.dart';
import 'package:wood_cft/domain/money.dart';

/// The service under test.
const BillingService _billing = BillingService();

/// The default policy (₹100 / ₹150 at 20 CFT inclusive).
final LoadingPolicy _policy = LoadingPolicy.standard;

/// Deterministic exploration config giving each property >= 100 iterations.
final ExploreConfig _explore =
    ExploreConfig(numRuns: 200, random: Random(20240711));

/// The three literal tax modes the property quantifies over.
const List<TaxMode> _modes = TaxMode.values;

/// Builds a goods bill with an explicit goods subtotal and exact total CFT,
/// without pricing lines (the property reasons about the totals, not the
/// line-by-line math already covered by Properties 14/15).
GoodsBill _billOf({required int goodsPaise, required Cft totalCft}) => GoodsBill(
      lines: const [],
      goodsSubtotal: Money.fromPaise(goodsPaise),
      totalCft: totalCft,
    );

void main() {
  group('Loading excluded from tax, added once after tax (Property 16, glados)',
      () {
    // Random goods subtotal in paise, a random exact total CFT (as thousandths
    // of a CFT so both tiers are reachable), and a tax-mode index.
    Glados3<int, int, int>(
      any.intInRange(0, 100000001), // goods paise: 0 .. ₹10,00,000
      any.intInRange(0, 60001), // totalCft × 1000: 0 .. 60 CFT
      any.intInRange(0, 3), // mode index 0..2
      _explore,
    ).test(
      'Feature: wood-cft-app, Property 16: Loading is excluded from tax, added '
      'once after tax - for all orders the taxable base equals the goods '
      'subtotal, exactly one loading charge is applied, '
      'payable = goods + tax + loading, and loading still applies in No-GST '
      '(Requirements 9.4, 10.4, 11.4, 11.5, 11.6)',
      (int goodsPaise, int cftMilli, int modeIndex) {
        final mode = _modes[modeIndex];
        final totalCft = Cft(Rational(BigInt.from(cftMilli), BigInt.from(1000)));
        final bill = _billOf(goodsPaise: goodsPaise, totalCft: totalCft);

        final totals = _billing.computeTotals(bill, mode);

        // Taxable base is the goods subtotal (loading excluded): the tax equals
        // the tax computed on the goods subtotal alone (Req 10.4, 11.5).
        final taxOnGoods = _billing.taxOnSubtotal(bill.goodsSubtotal, mode);
        expect(totals.tax, taxOnGoods,
            reason: 'tax must be on goods only, loading excluded');

        // Exactly one loading charge, equal to the single policy selection on
        // the exact total CFT (Req 11.4). For a non-empty order it is one of
        // the two tier amounts; for a zero-CFT order it is zero (Req 11.7).
        final loading = _billing.computeLoading(bill);
        expect(totals.loading, loading);
        if (totalCft.value > Rational.zero) {
          expect(loading == _policy.low || loading == _policy.high, isTrue,
              reason: 'a non-empty order gets exactly one tier amount');
        } else {
          expect(loading, Money.zero);
        }

        // payable = goods_subtotal + tax + loading (Req 11; design step 6).
        expect(totals.payable, bill.goodsSubtotal + totals.tax + totals.loading,
            reason: 'payable must be goods + tax + loading');

        // Loading is applied even in No-GST mode (Req 11.6): with zero tax the
        // payable is exactly goods + loading, and loading matches the tier.
        if (mode == TaxMode.noGst) {
          expect(totals.tax, Money.zero);
          expect(totals.payable, bill.goodsSubtotal + loading);
        }
      },
    );
  });

  group('Loading tier is a step function on exact CFT at 20 (Property 17, '
      'glados)', () {
    // Random exact total CFT as hundred-thousandths of a CFT, so values land
    // just below, exactly at, and just above the 20-CFT boundary - including
    // values whose 4-dp display rounds across 20 while the exact value is on
    // the other side.
    Glados<int>(
      any.intInRange(1, 4000001), // totalCft × 100000: >0 .. 40 CFT
      _explore,
    ).test(
      'Feature: wood-cft-app, Property 17: Loading tier is a step function on '
      'exact CFT at 20 - for all non-empty orders the charge is the low tier '
      'below 20 CFT and the high tier at or above 20 CFT (exactly 20 CFT -> '
      'high), compared on the exact CFT value, never the display-rounded value '
      '(Requirements 11.1, 11.2, 11.3)',
      (int cftHundredThousandths) {
        final totalCft = Cft(
          Rational(BigInt.from(cftHundredThousandths), BigInt.from(100000)),
        );
        final bill = _billOf(goodsPaise: 100000, totalCft: totalCft);

        final loading = _billing.computeLoading(bill);

        // The tier decision is made on the EXACT rational value, never the
        // 4-dp display string (Req 11.3).
        final atOrAbove20 = totalCft >= Cft.fromInt(20);
        if (atOrAbove20) {
          expect(loading, _policy.high,
              reason: 'exact CFT ${totalCft.value} (>= 20) must be ₹150; '
                  'display is ${totalCft.toFixed()}');
        } else {
          expect(loading, _policy.low,
              reason: 'exact CFT ${totalCft.value} (< 20) must be ₹100; '
                  'display is ${totalCft.toFixed()}');
        }

        // Step function: it is one of exactly two amounts, nothing in between.
        expect(loading == _policy.low || loading == _policy.high, isTrue);
      },
    );
  });
}
