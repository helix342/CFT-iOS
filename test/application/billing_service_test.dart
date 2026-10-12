// Pure-Dart unit tests for the goods-level BillingService (task 10.1).
//
// These pin the goods portion of design.md -> CFT and Currency Arithmetic ->
// Currency (steps 1–3) and Correctness Property 14:
//   * line_amount = exact_CFT × rate, rounded half-up to paise (Req 9.1, 9.2);
//   * goods_subtotal = Σ (independently rounded line amounts) (Req 9.3) — NOT a
//     single rounding of the exact sum;
//   * total sold volume = unrounded exact sum of per-line CFT (Req 9.6).
//
// Worked example (Req 21.8, as paired in the task spec): 50 pieces of a 2×1
// reaper at 6 ft = 50 × (2·1·6/144) = 50 × (1/12) = 25/6 CFT. At ₹400/CFT the
// exact goods value is (25/6)·400 = 5000/3 ₹ = 1666.666… → half-up → ₹1,666.67.
//
// A second line of the same 5000/3 ₹ value shows the sum-of-rounded-lines rule:
// each 5000/3 rounds to ₹1,666.67, so two lines sum to ₹3,333.34 — NOT the
// single rounding of 10000/3 = ₹3,333.33.
//
// Values are built through the real engine (`CalculationService.lineCftFor`)
// and the real money type (`Money` over integer paise), never doubles.
//
// Imports only the pure-Dart domain + application layers and the flutter_test
// matchers — no widgets are pumped.

import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/cft.dart';
import 'package:wood_cft/domain/money.dart';

void main() {
  const calc = CalculationService();
  const billing = BillingService(calc);

  // 2×1 reaper (bunch of 10) — the Req 21.8 cross-section.
  final reaper2x1 = CrossSection(
    id: 1,
    widthIn: 2,
    thicknessIn: 1,
    category: WoodCategory.reaper,
  );

  // ₹400 per CFT, exact.
  final rate400 = Rational.fromInt(400);

  group('line amount (Req 9.1, 9.2)', () {
    test('exact pre-rounding amount is allocatedCft × rate (no rounding)', () {
      // 50 pieces 2×1 @ 6 ft = 25/6 CFT.
      final cft = calc.lineCftFor(reaper2x1, 6, 50);
      expect(cft.value, Rational(BigInt.from(25), BigInt.from(6)));

      final exact = billing.exactLineAmountRupees(cft, rate400);
      // (25/6)·400 = 10000/6 = 5000/3 ₹ (exact, not yet rounded).
      expect(exact, Rational(BigInt.from(5000), BigInt.from(3)));
    });

    test('Req 21.8 single line rounds half-up to ₹1,666.67', () {
      final cft = calc.lineCftFor(reaper2x1, 6, 50);
      final amount = billing.lineAmount(cft, rate400);

      // 5000/3 ₹ = 166666.66… paise → half-up → 166667 paise = ₹1,666.67.
      expect(amount, Money.fromPaise(166667));
      expect(amount.format(), '\u20B91,666.67');
    });

    test('half-up boundary rounds a half-paise away from zero', () {
      // Pick an exact amount landing on the half-paise boundary: 0.005 ₹ =
      // 0.5 paise → half-up → 1 paise.
      final halfPaise = Cft(Rational(BigInt.one, BigInt.from(1000)));
      final amount = billing.lineAmount(halfPaise, Rational.fromInt(5));
      // (1/1000)·5 = 5/1000 = 0.005 ₹ = 0.5 paise → 1 paise.
      expect(amount, Money.fromPaise(1));
    });

    test('zero allocated CFT yields a zero line amount', () {
      expect(billing.lineAmount(Cft.zero, rate400), Money.zero);
    });
  });

  group('goods subtotal and total volume (Req 9.3, 9.6)', () {
    GoodsLineInput line(int qty, {int id = 1}) => GoodsLineInput(
          stockItemId: id,
          varietyId: 1,
          crossSectionId: reaper2x1.id,
          lengthFt: 6,
          allocatedCft: calc.lineCftFor(reaper2x1, 6, qty),
          rate: rate400,
        );

    test('Req 21.8 single-line goods subtotal is ₹1,666.67', () {
      final bill = billing.computeGoods([line(50)]);

      expect(bill.lines, hasLength(1));
      expect(bill.lines.single.amount, Money.fromPaise(166667));
      expect(bill.goodsSubtotal, Money.fromPaise(166667));
      expect(bill.goodsSubtotal.format(), '\u20B91,666.67');

      // Total sold volume is the exact unrounded 25/6 CFT.
      expect(bill.totalCft.value, Rational(BigInt.from(25), BigInt.from(6)));
    });

    test(
        'goods subtotal sums INDEPENDENTLY rounded lines '
        '(two 5000/3 lines → ₹3,333.34, not a single rounding of 10000/3)', () {
      final bill = billing.computeGoods([line(50, id: 1), line(50, id: 2)]);

      // Each line is 5000/3 ₹ → ₹1,666.67 (166667 paise) rounded on its own.
      expect(bill.lines.map((l) => l.amount).toList(),
          [Money.fromPaise(166667), Money.fromPaise(166667)]);

      // Sum of rounded lines = 333334 paise = ₹3,333.34 (Req 9.3).
      expect(bill.goodsSubtotal, Money.fromPaise(333334));
      expect(bill.goodsSubtotal.format(), '\u20B93,333.34');

      // A SINGLE rounding of the exact sum would be 10000/3 ₹ = 333333.33…
      // paise → ₹3,333.33 — which must NOT be the authoritative figure.
      final singleRoundingOfExactSum =
          Money.fromExactRupees(Rational(BigInt.from(10000), BigInt.from(3)));
      expect(singleRoundingOfExactSum, Money.fromPaise(333333));
      expect(bill.goodsSubtotal, isNot(singleRoundingOfExactSum));

      // Total volume is the exact unrounded sum: 25/6 + 25/6 = 25/3 CFT.
      expect(bill.totalCft.value, Rational(BigInt.from(25), BigInt.from(3)));
    });

    test('empty bill: no lines, zero subtotal, zero volume', () {
      final bill = billing.computeGoods(const <GoodsLineInput>[]);
      expect(bill.lines, isEmpty);
      expect(bill.goodsSubtotal, Money.zero);
      expect(bill.totalCft, Cft.zero);
    });
  });

  group('single-line literal GST (task 10.2; Req 10.1-10.5)', () {
    // A goods bill whose goods subtotal is exactly ₹1,000.00 (100000 paise):
    // 2.5 CFT at ₹400/CFT = 1000 ₹ exactly. 2.5 CFT = 50 pcs 2×1 @ 6 ft × … —
    // simplest: 30 pcs 2×1 @ 6 ft = 30 × 1/12 = 2.5 CFT, × ₹400 = ₹1,000.
    GoodsBill goodsBillOf1000() {
      final cft = calc.lineCftFor(reaper2x1, 6, 30); // 2.5 CFT
      final bill = billing.computeGoods([
        GoodsLineInput(
          stockItemId: 1,
          varietyId: 1,
          crossSectionId: reaper2x1.id,
          lengthFt: 6,
          allocatedCft: cft,
          rate: rate400,
        ),
      ]);
      // Guard the fixture: the taxable subtotal is exactly ₹1,000.00.
      expect(bill.goodsSubtotal, Money.fromPaise(100000));
      return bill;
    }

    test('TaxMode carries the single literal total rate (0, 9/100, 18/100)',
        () {
      expect(TaxMode.noGst.rate, Rational.zero);
      expect(TaxMode.nine.rate, Rational(BigInt.from(9), BigInt.from(100)));
      expect(
          TaxMode.eighteen.rate, Rational(BigInt.from(18), BigInt.from(100)));
    });

    // Req 21.17 — the three tax modes computed as a SINGLE tax line on a
    // ₹1,000 taxable subtotal: No GST → ₹0; 9% → ₹90; 18% → ₹180.
    test('Req 21.17 No GST → zero tax (Req 10.5)', () {
      final bill = goodsBillOf1000();
      expect(billing.computeTax(bill, TaxMode.noGst), Money.zero);
    });

    test('Req 21.17 literal 9% → ₹90 as a single line', () {
      final bill = goodsBillOf1000();
      final tax = billing.computeTax(bill, TaxMode.nine);
      // 1000 × 9/100 = 90 ₹ exactly.
      expect(tax, Money.fromPaise(9000));
      expect(tax.format(), '\u20B990.00');
    });

    test('Req 21.17 / 21.18 literal 18% → ₹180 as a single line', () {
      final bill = goodsBillOf1000();
      final tax = billing.computeTax(bill, TaxMode.eighteen);
      // 1000 × 18/100 = 180 ₹ exactly (the ₹1,280 payable incl. loading is
      // task 10.3).
      expect(tax, Money.fromPaise(18000));
      expect(tax.format(), '\u20B9180.00');
    });

    test('No GST tax is zero regardless of subtotal (Req 10.5)', () {
      expect(
        billing.taxOnSubtotal(Money.fromPaise(1234567), TaxMode.noGst),
        Money.zero,
      );
    });

    test('tax rounds half-up to paise on an exact product (Req 10.3)', () {
      // Subtotal ₹1.05 → 9% = 0.0945 ₹ = 9.45 paise → half-up → 9 paise.
      expect(
        billing.taxOnSubtotal(Money.fromPaise(105), TaxMode.nine),
        Money.fromPaise(9),
      );
      // Subtotal ₹0.25 → 18% = 0.045 ₹ = 4.5 paise → half-up → 5 paise.
      expect(
        billing.taxOnSubtotal(Money.fromPaise(25), TaxMode.eighteen),
        Money.fromPaise(5),
      );
    });

    test('taxable subtotal is the goods subtotal (loading excluded, Req 10.4)',
        () {
      // computeTax reads the bill's goodsSubtotal only; there is no loading
      // input, so the taxable base is the goods subtotal by construction.
      final bill = goodsBillOf1000();
      expect(
        billing.computeTax(bill, TaxMode.eighteen),
        billing.taxOnSubtotal(bill.goodsSubtotal, TaxMode.eighteen),
      );
    });
  });

  group('loading charge + payable (task 10.3; Req 11.1-11.7)', () {
    // A goods bill at ₹400/CFT with a chosen piece count, so the exact total
    // sold CFT (and thus the loading tier) is controllable.
    GoodsBill goodsBill(int qty, {Rational? rate}) => billing.computeGoods([
          GoodsLineInput(
            stockItemId: 1,
            varietyId: 1,
            crossSectionId: reaper2x1.id,
            lengthFt: 6,
            allocatedCft: calc.lineCftFor(reaper2x1, 6, qty),
            rate: rate ?? rate400,
          ),
        ]);

    test('LoadingPolicy.standard is ₹100 / ₹150 at 20 CFT inclusive', () {
      final p = LoadingPolicy.standard;
      expect(p.low, Money.fromPaise(10000)); // ₹100
      expect(p.high, Money.fromPaise(15000)); // ₹150
      expect(p.thresholdCft, Cft.fromInt(20));
      expect(p.thresholdInclusive, isTrue);
    });

    // Req 21.8 — 50 pcs 2×1 @ 6 ft = 25/6 CFT (≈4.1667, well under 20) at
    // ₹400/CFT → goods ₹1,666.67; No GST; loading ₹100 → payable ₹1,766.67.
    test('Req 21.8 No GST, order < 20 CFT → loading ₹100, payable ₹1,766.67',
        () {
      final bill = goodsBill(50);
      expect(bill.goodsSubtotal, Money.fromPaise(166667)); // ₹1,666.67
      expect(bill.totalCft.value, Rational(BigInt.from(25), BigInt.from(6)));

      final loading = billing.computeLoading(bill);
      expect(loading, Money.fromPaise(10000)); // ₹100 (order < 20 CFT)

      final totals = billing.computeTotals(bill, TaxMode.noGst);
      expect(totals.tax, Money.zero);
      expect(totals.loading, Money.fromPaise(10000));
      expect(totals.payable, Money.fromPaise(176667)); // ₹1,766.67
      expect(totals.payable.format(), '\u20B91,766.67');
    });

    // Req 21.16 — loading tiers on EXACT CFT at the 20-CFT boundary. The
    // comparison must use the exact rational value, never the 4-dp display.
    group('Req 21.16 loading tiers on exact CFT at the 20 threshold', () {
      Money loadingForCft(Cft totalCft) {
        // Build a one-line bill whose totalCft is exactly `totalCft` by
        // injecting it directly (rate is irrelevant to the tier).
        final bill = GoodsBill(
          lines: const [],
          goodsSubtotal: Money.zero,
          totalCft: totalCft,
        );
        return billing.computeLoading(bill);
      }

      test('just below 20 CFT → ₹100', () {
        // 19.9999 CFT exact → low tier.
        final justBelow = Cft(Rational(BigInt.from(199999), BigInt.from(10000)));
        expect(justBelow < Cft.fromInt(20), isTrue);
        expect(loadingForCft(justBelow), Money.fromPaise(10000));
      });

      test('exactly 20 CFT → ₹150 (inclusive high tier)', () {
        expect(loadingForCft(Cft.fromInt(20)), Money.fromPaise(15000));
      });

      test('just above 20 CFT → ₹150', () {
        // 20.0001 CFT exact → high tier.
        final justAbove =
            Cft(Rational(BigInt.from(200001), BigInt.from(10000)));
        expect(justAbove > Cft.fromInt(20), isTrue);
        expect(loadingForCft(justAbove), Money.fromPaise(15000));
      });

      test(
          'exact value, not the 4-dp display, decides the tier '
          '(display rounds across 20 but exact is below)', () {
        // 19.99996 CFT: 4-dp display rounds to "20.0000" yet the exact value
        // is strictly below 20, so it must stay in the ₹100 tier.
        final belowButRoundsUp =
            Cft(Rational(BigInt.from(1999996), BigInt.from(100000)));
        expect(belowButRoundsUp.toFixed(), '20.0000'); // display rounds across
        expect(belowButRoundsUp < Cft.fromInt(20), isTrue); // exact is below
        expect(loadingForCft(belowButRoundsUp), Money.fromPaise(10000));
      });

      test(
          'exact value, not the 4-dp display, decides the tier '
          '(display rounds below 20 but exact is at/above)', () {
        // 20.00004 CFT: 4-dp display rounds to "20.0000" but the exact value
        // is strictly above 20, so it must be the ₹150 tier.
        final aboveButRoundsDown =
            Cft(Rational(BigInt.from(2000004), BigInt.from(100000)));
        expect(aboveButRoundsDown.toFixed(), '20.0000');
        expect(aboveButRoundsDown > Cft.fromInt(20), isTrue);
        expect(loadingForCft(aboveButRoundsDown), Money.fromPaise(15000));
      });
    });

    // Req 21.18 — goods ₹1,000 + loading ₹100 at literal 18% with loading
    // UNTAXED → tax ₹180 (on goods only), payable ₹1,280.
    test('Req 21.18 18% with loading untaxed → tax ₹180, payable ₹1,280', () {
      // 30 pcs 2×1 @ 6 ft = 2.5 CFT (< 20) at ₹400/CFT → goods ₹1,000.
      final bill = goodsBill(30);
      expect(bill.goodsSubtotal, Money.fromPaise(100000)); // ₹1,000.00

      final totals = billing.computeTotals(bill, TaxMode.eighteen);
      // Tax is on the goods subtotal only — loading excluded from the base.
      expect(totals.tax, Money.fromPaise(18000)); // ₹180.00
      expect(totals.loading, Money.fromPaise(10000)); // ₹100 (< 20 CFT)
      // payable = 1000 + 180 + 100 = ₹1,280.00.
      expect(totals.payable, Money.fromPaise(128000));
      expect(totals.payable.format(), '\u20B91,280.00');
      // Loading was NOT taxed: tax == 18% of goods only, not of goods+loading.
      expect(totals.tax,
          billing.taxOnSubtotal(bill.goodsSubtotal, TaxMode.eighteen));
    });

    test('loading still applies in No-GST mode (Req 11.6)', () {
      final bill = goodsBill(30); // 2.5 CFT, goods ₹1,000
      final totals = billing.computeTotals(bill, TaxMode.noGst);
      expect(totals.tax, Money.zero);
      expect(totals.loading, Money.fromPaise(10000)); // still ₹100
      expect(totals.payable, Money.fromPaise(110000)); // ₹1,100.00
    });

    test('empty / zero-CFT order carries NO loading (Req 11.7)', () {
      final empty = billing.computeGoods(const <GoodsLineInput>[]);
      expect(empty.totalCft, Cft.zero);
      expect(billing.computeLoading(empty), Money.zero);

      final totals = billing.computeTotals(empty, TaxMode.eighteen);
      expect(totals.loading, Money.zero);
      expect(totals.payable, Money.zero); // 0 + 0 + 0
    });

    test('a custom LoadingPolicy overrides the tier amounts/threshold', () {
      final bill = goodsBill(50); // 25/6 CFT ≈ 4.17
      final policy = LoadingPolicy(
        low: Money.fromRupees(50),
        high: Money.fromRupees(75),
        thresholdCft: Cft.fromInt(4),
      );
      // 4.17 >= 4 → high tier (₹75).
      expect(billing.computeLoading(bill, policy: policy),
          Money.fromRupees(75));
    });
  });

  group('GoodsLineInput validation', () {
    test('rejects a non-positive rate', () {
      expect(
        () => GoodsLineInput(
          stockItemId: 1,
          varietyId: 1,
          crossSectionId: 1,
          lengthFt: 6,
          allocatedCft: Cft.fromInt(1),
          rate: Rational.zero,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative allocated CFT', () {
      expect(
        () => GoodsLineInput(
          stockItemId: 1,
          varietyId: 1,
          crossSectionId: 1,
          lengthFt: 6,
          allocatedCft: Cft(Rational.fromInt(-1)),
          rate: Rational.fromInt(400),
        ),
        throwsArgumentError,
      );
    });
  });
}
