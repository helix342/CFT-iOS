/// The goods-level money engine for the billing flow (task 10.1).
///
/// `BillingService` is the headless application-layer calculator for the
/// **goods** portion of an invoice (design.md -> CFT and Currency Arithmetic ->
/// Currency, steps 1–3): per-line amounts, the goods subtotal, and the exact
/// total sold volume. It is a pure value computation — no tax, no loading, no
/// persistence, no UI — so it runs headless under `flutter test` on Windows.
///
/// The money rule it implements (design.md Currency steps 1–3; Correctness
/// Property 14):
///
/// 1. `line_amount = exact_CFT × rate` computed in **exact rational**
///    arithmetic — the allocated CFT is an exact [Cft] and the rate is an exact
///    `₹/CFT` [Rational], so the product is exact before any rounding
///    (Requirement 9.1).
/// 2. **Each line is rounded half-up to paise** via `Money.fromExactRupees`
///    (Requirement 9.2).
/// 3. `goods_subtotal = Σ (rounded line amounts)` — the subtotal is the sum of
///    the per-line amounts that have **already been rounded**, NOT a single
///    rounding of the exact sum (Requirement 9.3). Because each line is rounded
///    independently before summing, this can differ by a paise or two from the
///    exact sum rounded once; the sum-of-rounded-lines figure is the
///    authoritative one (design.md Reconciliation note).
///
/// Separately it exposes the exact total sold volume as the **unrounded** sum
/// of the per-line exact CFT (Requirement 9.6), routed through the single
/// shared `CalculationService.totalCft` so previews, invoices, and the later
/// loading-tier comparison all agree on the volume.
///
/// Tax (task 10.2) is a single **literal** tax line on the taxable subtotal
/// (see [TaxMode] and [BillingService.computeTax]). Loading and the payable
/// grand total (task 10.3) are the flat once-per-order [LoadingPolicy] charge
/// and the `goods + tax + loading` identity, exposed via
/// [BillingService.computeLoading] and [BillingService.computeTotals]
/// ([InvoiceTotals]). [GoodsBill] is the goods-level value these build on.
///
/// Architecture rule (design.md): this service depends on `domain` and the
/// shared `CalculationService` only and MUST NOT import `package:flutter/*` or
/// `dart:io`.
library;

import 'package:meta/meta.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/domain/cft.dart';
import 'package:wood_cft/domain/money.dart';

/// The literal total tax rate applied to the taxable subtotal (Requirement 10;
/// design.md -> CFT and Currency Arithmetic step 4; Data Models -> TaxPolicy).
///
/// Each mode carries **one literal total rate** expressed as an exact
/// [Rational] (`0`, `9/100`, `18/100`). The computed tax is always presented as
/// a **single tax line** (CD-5) and is NEVER split into separate CGST + SGST
/// components (Requirements 10.1, 10.2) — the enum has no half-rate and the
/// service exposes only one tax figure, so a split is unrepresentable.
enum TaxMode {
  /// No GST: the tax rate is exactly zero, so the computed tax is always
  /// [Money.zero] (Requirement 10.5).
  noGst(0, 1, 'No GST'),

  /// A single literal **9%** total tax line: rate `9/100` (Requirement 10.1).
  nine(9, 100, 'GST 9%'),

  /// A single literal **18%** total tax line: rate `18/100` (Requirement 10.1).
  eighteen(18, 100, 'GST 18%');

  const TaxMode(this._rateNum, this._rateDen, this.label);

  final int _rateNum;
  final int _rateDen;

  /// A short human-readable label for the single tax line (e.g. `GST 18%`).
  ///
  /// This is a single combined label; it is intentionally not a CGST/SGST pair,
  /// reinforcing that the bill shows one literal tax line (Requirement 10.2).
  final String label;

  /// The exact literal total tax rate as a [Rational] (`0`, `9/100`, `18/100`).
  ///
  /// This is the full literal rate that multiplies the taxable subtotal — never
  /// a halved CGST/SGST component (Requirements 10.1, 10.3).
  Rational get rate => Rational(BigInt.from(_rateNum), BigInt.from(_rateDen));
}

/// The flat loading-charge policy: the two tier amounts and the exact-CFT
/// threshold that selects between them (task 10.3; Requirement 11; design.md ->
/// Data Models -> LoadingPolicy; CD-6).
///
/// The loading charge is a **flat** fee added **once per order after tax**,
/// chosen from the **exact** total sold CFT by a two-tier step function:
///
/// * total CFT **below** the threshold → the [low] amount (default ₹100), and
/// * total CFT **at or above** the threshold → the [high] amount (default
///   ₹150) — exactly 20 CFT yields the high tier (Requirements 11.1, 11.2;
///   CD-6).
///
/// The threshold defaults to **20 CFT, inclusive** so that *exactly 20* selects
/// the high tier. The comparison is always performed on the exact [Cft] value
/// and NEVER on a display-rounded figure (Requirement 11.3), so a volume whose
/// 4-decimal display rounds across 20 is still tiered by its true value.
///
/// The amounts and threshold are configurable (so a later Settings surface can
/// edit the policy — design.md LoadingPolicy singleton) but default to the
/// confirmed ₹100 / ₹150 at 20-inclusive values.
@immutable
class LoadingPolicy {
  /// Creates a loading policy from its two tier [low]/[high] amounts, the
  /// [thresholdCft] that separates them, and whether the threshold is
  /// [thresholdInclusive] (exactly-threshold → high tier).
  const LoadingPolicy({
    required this.low,
    required this.high,
    required this.thresholdCft,
    this.thresholdInclusive = true,
  });

  /// The confirmed default policy: ₹100 below 20 CFT, ₹150 at or above 20 CFT
  /// (exactly 20 → ₹150), matching CD-6 and design.md's LoadingPolicy defaults
  /// (`low_paise = 10000`, `high_paise = 15000`, `threshold_cft = 20`,
  /// `threshold_inclusive = true`).
  static final LoadingPolicy standard = LoadingPolicy(
    low: Money.fromRupees(100),
    high: Money.fromRupees(150),
    thresholdCft: Cft.fromInt(20),
  );

  /// The charge for an order **below** the threshold (default ₹100 =
  /// 10,000 paise).
  final Money low;

  /// The charge for an order **at or above** the threshold (default ₹150 =
  /// 15,000 paise).
  final Money high;

  /// The exact CFT boundary between the [low] and [high] tiers (default 20).
  final Cft thresholdCft;

  /// Whether an order whose exact total CFT equals [thresholdCft] falls into
  /// the [high] tier (default `true` — exactly 20 CFT → ₹150, Requirement
  /// 11.2 / CD-6).
  final bool thresholdInclusive;

  /// Selects the loading charge for an order of exact [totalCft], once per
  /// order (Requirement 11.4).
  ///
  /// The comparison uses the exact [Cft] value, never a display-rounded one
  /// (Requirement 11.3): the order is in the [high] tier when `totalCft`
  /// exceeds [thresholdCft], or equals it while [thresholdInclusive] is set
  /// (exactly 20 → ₹150); otherwise it is in the [low] tier.
  ///
  /// A **zero** total CFT yields [Money.zero] — an empty order carries no
  /// loading charge (Requirement 11.7). This is checked before the tiers, so a
  /// zero-CFT order is never charged the [low] amount.
  Money chargeFor(Cft totalCft) {
    // Empty / zero-CFT order (and, by the same guard, a receiving or cancelled
    // order that produced no sold volume) carries NO loading (Req 11.7).
    if (totalCft.value <= Rational.zero) {
      return Money.zero;
    }
    final atOrAboveThreshold = thresholdInclusive
        ? totalCft >= thresholdCft
        : totalCft > thresholdCft;
    return atOrAboveThreshold ? high : low;
  }

  @override
  String toString() => 'LoadingPolicy(low: ${low.format()}, '
      'high: ${high.format()}, thresholdCft: ${thresholdCft.toFixed()}, '
      'inclusive: $thresholdInclusive)';
}

/// The complete bill math for an order: goods subtotal, the single tax line,
/// the loading charge, and the payable grand total, with the exact total sold
/// volume (task 10.3).
///
/// This is the final value the finalize / preview flows consume. The money
/// identity it carries is (design.md Currency steps 3–6):
///
/// ```text
/// payable = goodsSubtotal + tax + loading
/// ```
///
/// where [tax] is the single literal tax line on the goods subtotal (loading
/// excluded from the taxable base — Requirement 10.4 / 11.5) and [loading] is
/// the flat once-per-order charge chosen from [totalCft] (Requirement 11). No
/// whole-rupee rounding is applied to any figure (OD-8); each is an exact
/// [Money] over integer paise.
@immutable
class InvoiceTotals {
  /// Creates the full invoice totals.
  const InvoiceTotals({
    required this.goodsSubtotal,
    required this.tax,
    required this.taxMode,
    required this.loading,
    required this.payable,
    required this.totalCft,
  });

  /// The goods subtotal = sum of the independently rounded line amounts
  /// (Requirement 9.3); this is also the taxable base (loading excluded).
  final Money goodsSubtotal;

  /// The single literal tax line on [goodsSubtotal] (Requirement 10).
  final Money tax;

  /// The tax mode that produced [tax] (carries its label for the invoice).
  final TaxMode taxMode;

  /// A short label for the tax line (e.g. `GST 18%` / `No GST`).
  String get taxLabel => taxMode.label;

  /// The flat loading charge, chosen once from [totalCft] and added after tax
  /// (Requirement 11); [Money.zero] for an empty / zero-CFT order.
  final Money loading;

  /// The payable grand total = `goodsSubtotal + tax + loading` (Requirement
  /// 11; design.md Currency step 6).
  final Money payable;

  /// The exact total sold volume the loading tier was chosen from (unrounded).
  final Cft totalCft;

  @override
  String toString() => 'InvoiceTotals(goods: ${goodsSubtotal.format()}, '
      'tax: ${tax.format()} ($taxLabel), loading: ${loading.format()}, '
      'payable: ${payable.format()}, totalCft: ${totalCft.toFixed()})';
}

/// A single priced goods line: an exact allocated volume at an exact `₹/CFT`
/// rate, carrying the identifying keys the invoice needs.
///
/// This is the input to [BillingService]: the exact [allocatedCft] (from the
/// allocator / shared `CalculationService`) and the exact [rate] (from
/// `PricingService`, `₹` per CFT, GST-exclusive). The identity fields let a
/// caller map a computed [GoodsLine] back to the SKU it priced; they do not
/// affect the money math.
@immutable
class GoodsLineInput {
  /// Creates a priced goods-line input.
  ///
  /// [rate] is `₹` per CFT and must be strictly positive (a missing rate is a
  /// `PricingService` concern surfaced before billing — a line reaching the
  /// billing engine must be priced).
  GoodsLineInput({
    required this.stockItemId,
    required this.varietyId,
    required this.crossSectionId,
    required this.lengthFt,
    required this.allocatedCft,
    required this.rate,
  }) {
    if (rate <= Rational.zero) {
      throw ArgumentError.value(
        rate,
        'rate',
        'rate (₹/CFT) must be strictly positive',
      );
    }
    if (allocatedCft.value < Rational.zero) {
      throw ArgumentError.value(
        allocatedCft,
        'allocatedCft',
        'allocated CFT must not be negative',
      );
    }
  }

  /// The source stock item this line draws from.
  final int stockItemId;

  /// The source variety.
  final int varietyId;

  /// The source cross-section.
  final int crossSectionId;

  /// The piece length in feet.
  final int lengthFt;

  /// The exact allocated volume for this line (never a binary `double`).
  final Cft allocatedCft;

  /// The exact `₹/CFT` rate (GST-exclusive) applied to [allocatedCft].
  final Rational rate;

  @override
  String toString() =>
      'GoodsLineInput(stockItemId: $stockItemId, lengthFt: $lengthFt, '
      'allocatedCft: ${allocatedCft.toFixed()}, rate: $rate)';
}

/// A priced goods line: its input identity plus the rounded line amount.
///
/// The [amount] is the exact `allocatedCft × rate` rounded **half-up to paise**
/// (Requirements 9.1, 9.2). [exactAmountRupees] is the exact pre-rounding rupee
/// product, retained so a reviewer (and Property 14) can confirm the rounding
/// was applied to the exact value and never to an intermediate `double`.
@immutable
class GoodsLine {
  /// Creates a computed goods line.
  const GoodsLine({
    required this.input,
    required this.exactAmountRupees,
    required this.amount,
  });

  /// The priced input this line was computed from.
  final GoodsLineInput input;

  /// The exact pre-rounding line amount in rupees (`allocatedCft × rate`),
  /// before the half-up-to-paise rounding (Requirement 9.1).
  final Rational exactAmountRupees;

  /// The line amount rounded half-up to paise (Requirement 9.2).
  final Money amount;

  @override
  String toString() =>
      'GoodsLine(amount: ${amount.format()}, '
      'exact: $exactAmountRupees, input: $input)';
}

/// The goods-level result of billing: the priced lines, the goods subtotal, and
/// the exact total sold volume.
///
/// This is a pure value object. Tax (task 10.2) and loading / payable
/// (task 10.3) build ON this result — e.g. the taxable subtotal is
/// [goodsSubtotal] and the loading tier reads [totalCft] — but none of that
/// math lives here.
@immutable
class GoodsBill {
  /// Creates a goods bill from its [lines], [goodsSubtotal], and [totalCft].
  const GoodsBill({
    required this.lines,
    required this.goodsSubtotal,
    required this.totalCft,
  });

  /// The priced lines, in input order, each with its half-up-rounded amount.
  final List<GoodsLine> lines;

  /// The goods subtotal = sum of the independently rounded line amounts
  /// (Requirement 9.3). [Money.zero] for an empty bill.
  final Money goodsSubtotal;

  /// The exact total sold volume = unrounded sum of the per-line exact CFT
  /// (Requirement 9.6). The later loading tier compares against this exact
  /// value, never a display-rounded one.
  final Cft totalCft;

  @override
  String toString() =>
      'GoodsBill(lines: ${lines.length}, '
      'goodsSubtotal: ${goodsSubtotal.format()}, '
      'totalCft: ${totalCft.toFixed()})';
}

/// Computes the goods portion of an invoice (task 10.1).
///
/// Pure and stateless; a single `const` instance can be shared across layers.
/// Tax and loading are later tasks that consume this service's output.
class BillingService {
  /// Creates the goods billing service using the shared [CalculationService]
  /// (defaults to a `const CalculationService()`), so the total volume it
  /// reports matches the stock views, allocation, and exports exactly.
  const BillingService([this._calc = const CalculationService()]);

  final CalculationService _calc;

  /// Computes a single line amount: the exact `allocatedCft × rate` rupee
  /// product rounded **half-up to paise** (Requirements 9.1, 9.2).
  ///
  /// The product is formed in exact rational arithmetic
  /// (`Cft.value × rate`) and the half-up rounding happens in
  /// `Money.fromExactRupees`, so no binary `double` ever touches the amount.
  /// Exposed on its own so the per-line rule can be pinned and property-tested
  /// independently of the subtotal.
  Money lineAmount(Cft allocatedCft, Rational rate) =>
      Money.fromExactRupees(exactLineAmountRupees(allocatedCft, rate));

  /// The exact, pre-rounding line amount in rupees: `allocatedCft × rate`
  /// (Requirement 9.1). Returned as a [Rational] so callers (and tests) can
  /// inspect the value the half-up rounding is applied to.
  Rational exactLineAmountRupees(Cft allocatedCft, Rational rate) =>
      allocatedCft.value * rate;

  /// Prices one [input] line into a [GoodsLine] (exact product + rounded
  /// amount).
  GoodsLine priceLine(GoodsLineInput input) {
    final exact = exactLineAmountRupees(input.allocatedCft, input.rate);
    return GoodsLine(
      input: input,
      exactAmountRupees: exact,
      amount: Money.fromExactRupees(exact),
    );
  }

  /// Computes the full goods bill for [inputs]: the priced lines, the goods
  /// subtotal (sum of the independently rounded line amounts — Requirement
  /// 9.3), and the exact total sold volume (unrounded sum of the per-line CFT —
  /// Requirement 9.6).
  ///
  /// An empty [inputs] yields an empty bill: no lines, a zero subtotal, and a
  /// zero total volume.
  GoodsBill computeGoods(Iterable<GoodsLineInput> inputs) {
    final lines = <GoodsLine>[];
    var subtotal = Money.zero;
    for (final input in inputs) {
      final line = priceLine(input);
      lines.add(line);
      // Goods subtotal sums the ALREADY-ROUNDED per-line amounts (Req 9.3),
      // never a single rounding of the exact sum.
      subtotal += line.amount;
    }

    // Total volume is the exact UNROUNDED sum of the per-line CFT (Req 9.6),
    // via the single shared engine so every surface agrees on the volume.
    final totalCft =
        _calc.totalCft([for (final line in lines) line.input.allocatedCft]);

    return GoodsBill(
      lines: List<GoodsLine>.unmodifiable(lines),
      goodsSubtotal: subtotal,
      totalCft: totalCft,
    );
  }

  /// Computes the single literal tax line for a [GoodsBill] under [mode]
  /// (task 10.2).
  ///
  /// The tax is `taxable_subtotal × literal_rate` where the taxable subtotal is
  /// the goods subtotal with **loading excluded** (loading itself is task 10.3,
  /// and is never part of the taxable base — Requirement 10.4; design.md
  /// step 4). It delegates to [taxOnSubtotal], passing the bill's
  /// [GoodsBill.goodsSubtotal].
  Money computeTax(GoodsBill bill, TaxMode mode) =>
      taxOnSubtotal(bill.goodsSubtotal, mode);

  /// Computes the single literal tax line for an explicit taxable [subtotal]
  /// under [mode] (task 10.2).
  ///
  /// The result is `subtotal × mode.rate`, rounded **half-up to paise** via
  /// `Money.fromExactRupees`, where `mode.rate` is the one literal total rate
  /// (`0`, `9/100`, `18/100` — Requirements 10.1, 10.3). For [TaxMode.noGst]
  /// the rate is zero so the tax is exactly [Money.zero] (Requirement 10.5).
  ///
  /// The returned value is a **single** tax figure (one tax line, CD-5), never
  /// a CGST + SGST pair (Requirement 10.2).
  ///
  /// [subtotal] is the taxable subtotal, which equals the goods subtotal with
  /// loading excluded (Requirement 10.4). The multiplication is exact: the
  /// subtotal's integer paise are lifted to a [Rational] and multiplied by the
  /// exact rate, so no binary `double` ever touches the tax.
  Money taxOnSubtotal(Money subtotal, TaxMode mode) {
    if (mode == TaxMode.noGst) {
      // No GST → zero tax (Requirement 10.5). Short-circuited so the result is
      // exactly Money.zero regardless of the subtotal.
      return Money.zero;
    }
    // Exact rupee value of the taxable subtotal = paise / 100.
    final subtotalRupees = Rational(subtotal.paise, _paisePerRupee);
    // tax = taxable_subtotal × literal_rate, rounded half-up to paise.
    return Money.fromExactRupees(subtotalRupees * mode.rate);
  }

  /// Computes the flat loading charge for a [GoodsBill] under [policy]
  /// (task 10.3; Requirement 11).
  ///
  /// The charge is chosen from the bill's **exact** total sold volume
  /// ([GoodsBill.totalCft]) by [policy], so the tier comparison uses the true
  /// rational CFT and never a display-rounded figure (Requirement 11.3). It is
  /// a single flat amount applied **once per order** (Requirement 11.4);
  /// an empty / zero-CFT order yields [Money.zero] (Requirement 11.7).
  ///
  /// [policy] defaults to [LoadingPolicy.standard] (₹100 below 20 CFT, ₹150 at
  /// or above 20 CFT inclusive — CD-6). The charge does not depend on the tax
  /// mode, so it still applies in No-GST mode (Requirement 11.6).
  Money computeLoading(GoodsBill bill, {LoadingPolicy? policy}) =>
      (policy ?? LoadingPolicy.standard).chargeFor(bill.totalCft);

  /// Computes the complete invoice totals for a [GoodsBill] under [mode] and
  /// [policy]: goods subtotal, the single tax line, the loading charge, and the
  /// payable grand total (task 10.3).
  ///
  /// This is the final bill math the finalize / preview flows consume. It wires
  /// the goods / tax / loading pieces into the design's Currency identity
  /// (design.md steps 3–6):
  ///
  /// 1. taxable base = [GoodsBill.goodsSubtotal] (loading excluded — Req 10.4 /
  ///    11.5);
  /// 2. `tax = taxable_subtotal × literal_rate` via [computeTax] (one tax line,
  ///    Req 10);
  /// 3. `loading` from the exact [GoodsBill.totalCft] via [computeLoading],
  ///    added **after** tax and still applied in No-GST mode (Req 11.4–11.6),
  ///    zero for an empty order (Req 11.7);
  /// 4. `payable = goods_subtotal + tax + loading` (Req 11; step 6).
  ///
  /// No whole-rupee rounding is applied — every figure stays exact paise
  /// (OD-8); display rounding to 2 dp with Indian grouping happens only in
  /// [Money.format].
  InvoiceTotals computeTotals(
    GoodsBill bill,
    TaxMode mode, {
    LoadingPolicy? policy,
  }) {
    final tax = computeTax(bill, mode);
    final loading = computeLoading(bill, policy: policy);
    // payable = goods_subtotal + tax + loading (loading added AFTER tax and
    // never part of the taxable base).
    final payable = bill.goodsSubtotal + tax + loading;
    return InvoiceTotals(
      goodsSubtotal: bill.goodsSubtotal,
      tax: tax,
      taxMode: mode,
      loading: loading,
      payable: payable,
      totalCft: bill.totalCft,
    );
  }

  static final BigInt _paisePerRupee = BigInt.from(100);
}
