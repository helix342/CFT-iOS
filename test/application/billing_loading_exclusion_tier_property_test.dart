// Property-based tests for task 10.5 - loading exclusion/placement and the
// loading tier step function.
//
// These implement the design's Correctness Properties 16 and 17 (design.md ->
// Correctness Properties; Requirements 9.4, 10.4, 11.1-11.6) over the shared
// `BillingService` (`computeTotals` / `computeLoading`) and the
// `LoadingPolicy.standard` tier function:
//
//   Property 16 - Loading is excluded from tax, added once after tax:
//     for all orders the taxable base is the goods subtotal ONLY (loading is
//     never taxed), exactly one loading charge is applied once per order,
//     payable = goods_subtotal + tax + loading, and the loading charge still
//     applies in No-GST mode (Requirements 9.4, 10.4, 11.4, 11.5, 11.6).
//
//   Property 17 - Loading tier is a step function on exact CFT at 20:
//     for all orders the loading charge is exactly ₹100 when the exact total
//     sold CFT is below 20 and exactly ₹150 at or above 20 (exactly 20 CFT ->
//     ₹150, inclusive boundary), decided on the EXACT rational CFT value and
//     never on the 4-dp display value; an empty order carries NO loading
//     (Requirements 11.1, 11.2, 11.3).
//
// PBT framework: `package:glados`. A seeded `ExploreConfig(numRuns:, random:)`
// fixes each property at >= 150 iterations from a deterministic `Random`, so a
// counterexample reproduces exactly. Glados re-exports `package:test`.
//
// This is a fresh, independent test file for task 10.5 (distinct from the
// existing loading property suite): it drives the properties through the full
// `computeTotals` path over actual priced goods lines and explicitly pins the
// exact-CFT boundary at 20 (just below, exactly at, just above). It imports
// only the application + domain layers, `package:glados`, and
// `package:rational`. No Flutter widgets, no IO. It does NOT touch production
// source.

import 'package:glados/glados.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/domain/cft.dart';
import 'package:wood_cft/domain/money.dart';

/// The shared service under test.
const BillingService _billing = BillingService();

/// The confirmed default policy: ₹100 below 20 CFT, ₹150 at or above 20 CFT
/// (exactly 20 -> ₹150, inclusive).
final LoadingPolicy _policy = LoadingPolicy.standard;

/// Deterministic exploration config: each property runs >= 150 iterations.
final ExploreConfig _explore =
    ExploreConfig(numRuns: 180, random: Random(0x10C4D));

/// The three literal tax modes the exclusion/placement property quantifies
/// over.
const List<TaxMode> _modes = TaxMode.values;

/// A fixed positive `₹/CFT` rate used to turn a target CFT into priced lines
/// (the rate value is immaterial to the loading math; it only produces a
/// non-trivial goods subtotal and tax base).
final Rational _rate = Rational(BigInt.from(1250)); // ₹1250 / CFT

/// Builds a goods bill from a list of exact per-line CFT values, priced at the
/// fixed [_rate], via the full `computeGoods` path. This yields a real goods
/// subtotal (sum of half-up-rounded lines) and an exact total CFT equal to the
/// unrounded sum of the lines - the two inputs the loading/tax math reads.
GoodsBill _billFromLineCfts(List<Cft> lineCfts) {
  final inputs = <GoodsLineInput>[];
  for (var i = 0; i < lineCfts.length; i++) {
    inputs.add(
      GoodsLineInput(
        stockItemId: i + 1,
        varietyId: 1,
        crossSectionId: 1,
        lengthFt: 6,
        allocatedCft: lineCfts[i],
        rate: _rate,
      ),
    );
  }
  return _billing.computeGoods(inputs);
}

/// Builds a single-line bill whose exact total CFT is [milliCft] / 1000.
GoodsBill _billOfMilliCft(int milliCft) =>
    _billFromLineCfts([Cft(Rational(BigInt.from(milliCft), BigInt.from(1000)))]);

void main() {
  group(
    'Loading excluded from tax, added once after tax (Property 16, glados)',
    () {
      // Random total CFT split across 1-3 lines (so multi-line orders are
      // exercised too), and a random tax-mode index. The CFT is generated as
      // thousandths so both tiers (below / at-or-above 20) are reachable.
      Glados3<int, int, int>(
        any.intInRange(0, 60001), // total CFT x 1000: 0 .. 60 CFT
        any.intInRange(1, 4), // line count: 1 .. 3
        any.intInRange(0, 3), // mode index 0..2
        _explore,
      ).test(
        'Feature: wood-cft-app, Property 16: Loading is excluded from tax, '
        'added once after tax - for all orders the taxable base is the goods '
        'subtotal only, exactly one loading charge is applied once per order, '
        'payable = goods + tax + loading, and loading still applies in No-GST '
        '(Requirements 9.4, 10.4, 11.4, 11.5, 11.6)',
        (int totalMilliCft, int lineCount, int modeIndex) {
          final mode = _modes[modeIndex];

          // Split the total CFT across `lineCount` lines (remainder on the
          // first line) so the exact total is preserved exactly.
          final base = totalMilliCft ~/ lineCount;
          final remainder = totalMilliCft - base * lineCount;
          final lineCfts = <Cft>[
            for (var i = 0; i < lineCount; i++)
              Cft(
                Rational(
                  BigInt.from(base + (i == 0 ? remainder : 0)),
                  BigInt.from(1000),
                ),
              ),
          ];
          final bill = _billFromLineCfts(lineCfts);

          final totals = _billing.computeTotals(bill, mode);

          // (1) Taxable base is the goods subtotal ONLY - loading is never part
          // of the taxable base (Req 10.4 / 11.5). The reported tax must equal
          // the tax computed on the goods subtotal alone, with loading having
          // no influence on it.
          final taxOnGoods = _billing.taxOnSubtotal(bill.goodsSubtotal, mode);
          expect(totals.tax, taxOnGoods,
              reason: 'tax must be on goods subtotal only; loading excluded');

          // (2) Exactly one loading charge, applied once per order, equal to
          // the single policy selection on the exact total CFT (Req 11.4). A
          // non-empty order gets exactly one of the two tier amounts; a
          // zero-CFT order gets none (Req 11.7).
          final loading = _billing.computeLoading(bill);
          expect(totals.loading, loading);
          if (bill.totalCft.value > Rational.zero) {
            expect(loading == _policy.low || loading == _policy.high, isTrue,
                reason: 'a non-empty order gets exactly one tier amount');
          } else {
            expect(loading, Money.zero,
                reason: 'an empty / zero-CFT order carries no loading');
          }

          // (3) Loading is added AFTER tax to form the payable:
          // payable = goods_subtotal + tax + loading (Req 11; design step 6).
          expect(
            totals.payable,
            bill.goodsSubtotal + totals.tax + totals.loading,
            reason: 'payable must be goods + tax + loading',
          );

          // (4) Loading still applies in No-GST mode (Req 11.6): with zero tax
          // the payable is exactly goods + loading, i.e. loading is independent
          // of the tax mode.
          if (mode == TaxMode.noGst) {
            expect(totals.tax, Money.zero);
            expect(totals.payable, bill.goodsSubtotal + loading);
          }

          // The loading charge is identical regardless of tax mode (added once,
          // placement after tax does not change which tier applies).
          final loadingNoGst = _billing
              .computeTotals(bill, TaxMode.noGst)
              .loading;
          expect(totals.loading, loadingNoGst,
              reason: 'the single loading charge is independent of tax mode');
        },
      );
    },
  );

  group(
    'Loading tier is a step function on exact CFT at 20 (Property 17, glados)',
    () {
      // Random exact total CFT as hundred-thousandths of a CFT, strictly
      // positive, spanning just-below / exactly-at / just-above the 20-CFT
      // boundary - including values whose 4-dp display rounds across 20 while
      // the exact value is on the other side.
      Glados<int>(
        any.intInRange(1, 4000001), // total CFT x 100000: >0 .. 40 CFT
        _explore,
      ).test(
        'Feature: wood-cft-app, Property 17: Loading tier is a step function on '
        'exact CFT at 20 - for all non-empty orders the charge is ₹100 below '
        '20 CFT and ₹150 at or above 20 CFT (exactly 20 -> ₹150), decided on '
        'the exact CFT value and never the display-rounded value '
        '(Requirements 11.1, 11.2, 11.3)',
        (int cftHundredThousandths) {
          final totalCft = Cft(
            Rational(BigInt.from(cftHundredThousandths), BigInt.from(100000)),
          );
          final bill = _billFromLineCfts([totalCft]);

          final loading = _billing.computeLoading(bill);

          // The tier decision is made on the EXACT rational value, never the
          // 4-dp display string (Req 11.3): exactly 20 CFT is the high tier
          // (inclusive boundary, Req 11.2).
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

          // Step function: the charge is one of exactly two amounts, with
          // nothing in between (Req 11.1).
          expect(loading == _policy.low || loading == _policy.high, isTrue,
              reason: 'the tier is a two-valued step function');
        },
      );

      // Pinned boundary examples: just below 20, exactly 20 (inclusive -> high),
      // just above 20, and the empty / zero-CFT order (no loading). These make
      // the step and the inclusive boundary explicit alongside the random run.
      test(
        'Feature: wood-cft-app, Property 17: exact-CFT boundary at 20 is '
        'inclusive (just-below -> ₹100, exactly 20 -> ₹150, just-above -> '
        '₹150) and an empty order carries no loading '
        '(Requirements 11.1, 11.2, 11.3, 11.7)',
        () {
          // Just below 20 (19.9999...) -> low tier ₹100.
          expect(
            _billing.computeLoading(_billOfMilliCft(19999)),
            _policy.low,
          );
          // Exactly 20 CFT -> high tier ₹150 (inclusive boundary).
          expect(
            _billing.computeLoading(_billFromLineCfts([Cft.fromInt(20)])),
            _policy.high,
          );
          // A hair above 20 (20.001) -> high tier ₹150.
          expect(
            _billing.computeLoading(_billOfMilliCft(20001)),
            _policy.high,
          );
          // Empty order -> no loading (Req 11.7).
          expect(
            _billing.computeLoading(_billFromLineCfts(const [])),
            Money.zero,
          );
          // Zero-CFT (a single zero-volume line) -> no loading (Req 11.7).
          expect(
            _billing.computeLoading(_billFromLineCfts([Cft.zero])),
            Money.zero,
          );
        },
      );
    },
  );
}
