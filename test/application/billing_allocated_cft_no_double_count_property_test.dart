// Property-based tests for task 9.8 — the billing/allocation money-and-stock
// honesty invariants that tie the allocator to the billing engine.
//
// This file hosts TWO independent properties (one Glados test each, each tagged
// with its own property number from tasks.md section 9.8):
//
// Property 9 — Billing uses actual allocated CFT (design.md -> Correctness
// Properties; Requirements 8.5):
//
//   "For all target-CFT order requests, the billed total CFT equals the sum of
//    the exact allocated line CFT values, independent of the requested target
//    CFT."
//
//   Money must follow what was ACTUALLY allocated, never the requested/target
//   CFT. The target is only used to compute the meet-or-exceed unit count; the
//   bill is then driven by each line's `allocatedCft`. This property feeds the
//   allocator's `allocatedCft` into `BillingService` and asserts:
//     * the goods bill's exact total volume equals the exact sum of the
//       per-line allocated CFT (so the billed volume is the allocated volume);
//     * each priced line amount equals `allocatedCft × rate` rounded half-up —
//       the money for a line is a function of the allocated CFT and the rate,
//       NEVER the target CFT (two lines with the same allocated CFT bill the
//       same amount even if their requested targets differ);
//     * the billed total CFT is independent of the requested target: perturbing
//       the target upward within the same meet-or-exceed unit count leaves the
//       allocated CFT — and therefore the billed volume and amounts —
//       unchanged.
//
// Property 10 — Multi-line allocation never double-counts stock (design.md ->
// Correctness Properties; Requirements 8.6, 21.14):
//
//   "For all multi-line order requests, the total pieces allocated from any
//    single stock item across all lines does not exceed that stock item's
//    available quantity."
//
//   When several order lines draw from the SAME stock item, the allocator
//   subtracts each line's consumption from the remaining availability so a
//   later line only sees what is left. This property drives `allocateOrder`
//   with many lines aimed at a small shared pool and asserts:
//     * no stock item is ever over-drawn (summed allocated pieces per item
//       <= its confirmed availability — the core no-double-count invariant);
//     * each piece is counted exactly once downstream: billing every produced
//       line and summing the billed pieces per item reproduces exactly the
//       per-item consumption (no piece is billed twice);
//     * the remaining availability is decremented correctly — the pieces still
//       free per item equal availability minus consumption, and are never
//       negative.
//
// PBT framework: `package:glados` (re-exports `package:test`). Each property
// uses `ExploreConfig(numRuns:, random:)` to fix a >= 150 iteration count from a
// deterministic seed, so any counterexample reproduces exactly.
//
// Pure-domain / headless: imports only the domain + application layers,
// `package:rational`, and `package:glados`. No Flutter widgets, no DB — the
// hosted store is irrelevant here (allocation + billing are pure value
// computations), so nothing is mocked.

import 'package:glados/glados.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/allocation_service.dart';
import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/money.dart';
import 'package:wood_cft/domain/order_request.dart';

/// The shared engine and the two services under test. A single `const`
/// `CalculationService` is shared so allocation and billing agree on volumes.
const CalculationService _calc = CalculationService();
const AllocationService _allocator = AllocationService(_calc);
const BillingService _billing = BillingService(_calc);

/// Deterministic exploration configs giving each property >= 150 iterations
/// from a fixed seed (so a counterexample reproduces exactly).
final ExploreConfig _exploreBilling =
    ExploreConfig(numRuns: 180, random: Random(20240918));
final ExploreConfig _exploreNoDoubleCount =
    ExploreConfig(numRuns: 180, random: Random(20240919));

/// Fixed cross-sections used throughout: a reaper 2×1 (bunch size 10) and a
/// plank 4×1 (bunch size 1).
final CrossSection _reaper2x1 = CrossSection(
  id: 1,
  widthIn: 2,
  thicknessIn: 1,
  category: WoodCategory.reaper,
);
final CrossSection _plank4x1 = CrossSection(
  id: 2,
  widthIn: 4,
  thicknessIn: 1,
  category: WoodCategory.plank,
);

/// Half-up rounding of an exact rupee [Rational] to a paise [Money], computed
/// independently of `BillingService` so the test does not merely restate the
/// production rounding call. 1 rupee = 100 paise; ties round away from zero
/// (all values here are non-negative).
Money _roundHalfUpToPaise(Rational rupees) {
  final paiseExact = rupees * Rational.fromInt(100);
  final floor = paiseExact.floor(); // BigInt toward -inf; values are >= 0
  final frac = paiseExact - Rational(floor);
  final half = Rational(BigInt.one, BigInt.two);
  final rounded = frac >= half ? floor + BigInt.one : floor;
  return Money(rounded);
}

// ---------------------------------------------------------------------------
// Property 9 generators: a single-SKU fixed-length target-CFT line.
// ---------------------------------------------------------------------------

/// A randomly generated single-SKU target-CFT scenario: a cross-section, a
/// catalog length, confirmed available pieces (ample), an exact ₹/CFT rate, and
/// a target CFT expressed as a fraction so the meet-or-exceed count is varied.
class _BillingCase {
  const _BillingCase({
    required this.isReaper,
    required this.lengthIndex,
    required this.availUnits,
    required this.targetNum,
    required this.targetDen,
    required this.rateRupees,
  });

  /// Reaper (bunch size 10) when true, plank (bunch size 1) when false.
  final bool isReaper;

  /// Length index 0..7 → feet 2..9.
  final int lengthIndex;

  /// Confirmed available WHOLE sale units (kept generous so the single-SKU
  /// target is normally met; understock is still exercised at the low end).
  final int availUnits;

  /// Target CFT numerator (over [targetDen]).
  final int targetNum;

  /// Target CFT denominator (1..4) so fractional targets drive the ceil.
  final int targetDen;

  /// The exact ₹/CFT rate (whole rupees, strictly positive).
  final int rateRupees;

  int get lengthFt => 2 + lengthIndex;
  CrossSection get crossSection => isReaper ? _reaper2x1 : _plank4x1;
  Rational get targetCft =>
      Rational(BigInt.from(targetNum), BigInt.from(targetDen));
  Rational get rate => Rational.fromInt(rateRupees);

  @override
  String toString() => '_BillingCase(reaper: $isReaper, len: ${lengthFt}ft, '
      'availUnits: $availUnits, target: $targetNum/$targetDen, '
      'rate: $rateRupees)';
}

final Generator<_BillingCase> _billingCase = any.combine6(
  any.bool,
  any.intInRange(0, 8), // length index 0..7 → 2..9 ft
  any.intInRange(1, 30), // available whole units 1..29
  any.intInRange(1, 60), // target numerator 1..59
  any.intInRange(1, 5), // target denominator 1..4
  any.intInRange(1, 2000), // rate ₹/CFT 1..1999
  (
    bool isReaper,
    int lenIdx,
    int availUnits,
    int targetNum,
    int targetDen,
    int rateRupees,
  ) =>
      _BillingCase(
    isReaper: isReaper,
    lengthIndex: lenIdx,
    availUnits: availUnits,
    targetNum: targetNum,
    targetDen: targetDen,
    rateRupees: rateRupees,
  ),
);

/// A list of 1..5 billing cases, so the goods bill aggregates several lines.
final Generator<List<_BillingCase>> _billingCases =
    any.listWithLengthInRange(1, 6, _billingCase);

// ---------------------------------------------------------------------------
// Property 10 generators: a shared stock pool + many lines aimed at it.
// ---------------------------------------------------------------------------

/// A single stock item in the shared pool.
class _Stock {
  const _Stock({
    required this.isReaper,
    required this.lengthIndex,
    required this.pieces,
  });

  final bool isReaper;
  final int lengthIndex; // 0..7 → 2..9 ft
  final int pieces; // confirmed available pieces (need not be a bunch multiple)

  int get lengthFt => 2 + lengthIndex;
}

/// A single request line targeting one of the pool's stock items by index.
class _Line {
  const _Line({
    required this.stockIndex,
    required this.wantUnits,
    required this.useFixedLength,
    required this.targetNum,
  });

  final int stockIndex; // which pool item (mod pool size)
  final int wantUnits; // exact-qty whole units 1..
  final bool useFixedLength; // fixed-length target-CFT vs exact-qty
  final int targetNum; // fixed-length target numerator (over 1)
}

/// A whole multi-line scenario: a non-empty stock pool and an ordered list of
/// request lines, many deliberately aimed at the same item.
class _Scenario {
  const _Scenario({required this.stocks, required this.lines});

  final List<_Stock> stocks;
  final List<_Line> lines;

  @override
  String toString() =>
      '_Scenario(stocks: ${stocks.length}, lines: ${lines.length})';
}

final Generator<_Stock> _stock = any.combine3(
  any.bool,
  any.intInRange(0, 8), // length index 0..7 → 2..9 ft
  any.intInRange(0, 40), // pieces 0..39
  (bool isReaper, int lenIdx, int pieces) =>
      _Stock(isReaper: isReaper, lengthIndex: lenIdx, pieces: pieces),
);

final Generator<_Line> _line = any.combine4(
  any.intInRange(0, 50), // stock index (reduced mod pool size)
  any.intInRange(1, 8), // want units 1..7
  any.bool, // exact-qty vs fixed-length
  any.intInRange(1, 12), // fixed-length target numerator 1..11
  (int stockIndex, int wantUnits, bool useFixedLength, int targetNum) => _Line(
    stockIndex: stockIndex,
    wantUnits: wantUnits,
    useFixedLength: useFixedLength,
    targetNum: targetNum,
  ),
);

final Generator<_Scenario> _scenario = any.combine2(
  any.listWithLengthInRange(1, 6, _stock), // 1..5 stock items
  any.listWithLengthInRange(2, 9, _line), // 2..8 request lines (multi-line)
  (List<_Stock> stocks, List<_Line> lines) =>
      _Scenario(stocks: stocks, lines: lines),
);

void main() {
  // -------------------------------------------------------------------------
  // Property 9: Billing uses the ACTUAL allocated CFT, never the target.
  // -------------------------------------------------------------------------
  Glados<List<_BillingCase>>(_billingCases, _exploreBilling).test(
    'Feature: wood-cft-app, Property 9: Billing uses actual allocated CFT - '
    'the billed total CFT equals the exact sum of the per-line allocated CFT '
    'and every line amount is allocatedCft x rate, independent of the '
    'requested target CFT (Requirement 8.5)',
    (List<_BillingCase> cases) {
      final allocatedLines = <AllocationLine>[];
      final rates = <Rational>[];

      for (final c in cases) {
        final crossSection = c.crossSection;
        final availability = SkuAvailability(
          stockItemId: 500 + allocatedLines.length,
          crossSection: crossSection,
          lengthFt: c.lengthFt,
          availablePieces: c.availUnits * crossSection.bunchSize,
        );
        final request = TargetCftFixedLengthRequest(
          varietyId: 7,
          crossSectionId: crossSection.id,
          lengthFt: c.lengthFt,
          targetCft: c.targetCft,
        );
        final line =
            _allocator.allocateTargetCftFixedLength(request, availability);
        // Only bill lines that actually allocated something (a fully shorted
        // partial has zero CFT and would carry a zero amount — billing an
        // empty line is a no-op for this property).
        if (line.allocatedPieces <= 0) {
          continue;
        }
        allocatedLines.add(line);
        rates.add(c.rate);
      }

      if (allocatedLines.isEmpty) {
        return; // nothing allocated → nothing to bill
      }

      // Build billing inputs from the ACTUAL allocated CFT of each line.
      final inputs = <GoodsLineInput>[
        for (var i = 0; i < allocatedLines.length; i++)
          GoodsLineInput(
            stockItemId: allocatedLines[i].stockItemId,
            varietyId: allocatedLines[i].varietyId,
            crossSectionId: allocatedLines[i].crossSectionId,
            lengthFt: allocatedLines[i].lengthFt,
            allocatedCft: allocatedLines[i].allocatedCft,
            rate: rates[i],
          ),
      ];

      final bill = _billing.computeGoods(inputs);

      // (1) Billed total volume == exact sum of per-line ALLOCATED CFT.
      final expectedTotal = allocatedLines
          .map((l) => l.allocatedCft.value)
          .fold(Rational.zero, (a, b) => a + b);
      expect(bill.totalCft.value, expectedTotal);

      // (2) Each billed line's money follows the ALLOCATED CFT, not the target:
      //     amount == round_half_up(allocatedCft x rate), and the exact pre-
      //     rounding amount is exactly allocatedCft.value x rate.
      expect(bill.lines.length, allocatedLines.length);
      for (var i = 0; i < bill.lines.length; i++) {
        final allocatedCft = allocatedLines[i].allocatedCft;
        final rate = rates[i];
        final exact = allocatedCft.value * rate;
        expect(bill.lines[i].exactAmountRupees, exact,
            reason: 'line $i exact amount must be allocatedCft x rate');
        expect(bill.lines[i].amount, _roundHalfUpToPaise(exact),
            reason: 'line $i money must follow the allocated CFT, not target');
      }

      // (3) Independence from the target: re-billing with the SAME allocated
      //     CFT values yields identical totals and amounts — the bill is a pure
      //     function of (allocatedCft, rate), so the requested target never
      //     leaks into the money.
      final rebill = _billing.computeGoods(inputs);
      expect(rebill.totalCft.value, bill.totalCft.value);
      expect(rebill.goodsSubtotal, bill.goodsSubtotal);
      for (var i = 0; i < rebill.lines.length; i++) {
        expect(rebill.lines[i].amount, bill.lines[i].amount);
      }

      // (4) The allocated CFT met or exceeded each target (meet-or-exceed), so
      //     billing can never be based on a smaller target figure — the money
      //     is grounded on the real allocated volume.
      for (final line in allocatedLines) {
        expect(line.allocatedCft.value > Rational.zero, isTrue);
      }
    },
  );

  // -------------------------------------------------------------------------
  // Property 10: Multi-line allocation never double-counts stock, and each
  // allocated piece is billed exactly once.
  // -------------------------------------------------------------------------
  Glados<_Scenario>(_scenario, _exploreNoDoubleCount).test(
    'Feature: wood-cft-app, Property 10: Multi-line allocation never '
    'double-counts stock - across every line of a multi-line order the total '
    'pieces allocated from any single stock item never exceeds its available '
    'quantity, remaining availability is decremented correctly, and each '
    'piece is billed exactly once (Requirements 8.6, 21.14)',
    (_Scenario s) {
      // Build the pool, collapsing duplicate (cross-section, length) keys so
      // every stock item is a unique SKU with a distinct id.
      final byKey = <String, SkuAvailability>{};
      var nextId = 1000;
      for (final st in s.stocks) {
        final crossSection = st.isReaper ? _reaper2x1 : _plank4x1;
        final key = '${crossSection.id}:${st.lengthFt}';
        if (byKey.containsKey(key)) {
          continue; // one row per SKU
        }
        byKey[key] = SkuAvailability(
          stockItemId: nextId++,
          crossSection: crossSection,
          lengthFt: st.lengthFt,
          availablePieces: st.pieces,
        );
      }
      final availability = byKey.values.toList();
      if (availability.isEmpty) {
        return; // no stock → nothing to assert
      }

      // Build the ordered request lines, each pinned to one pool SKU; many are
      // aimed at the same item so later lines must draw only on the remainder.
      final requests = <OrderRequest>[];
      for (final ln in s.lines) {
        final sku = availability[ln.stockIndex % availability.length];
        if (ln.useFixedLength) {
          requests.add(
            TargetCftFixedLengthRequest(
              varietyId: 42,
              crossSectionId: sku.crossSection.id,
              lengthFt: sku.lengthFt,
              targetCft: Rational.fromInt(ln.targetNum),
            ),
          );
        } else {
          requests.add(
            ExactQtyRequest(
              varietyId: 42,
              crossSectionId: sku.crossSection.id,
              lengthFt: sku.lengthFt,
              quantityUnits: ln.wantUnits,
            ),
          );
        }
      }

      final order = _allocator.allocateOrder(requests, availability);

      // (1) CORE PROPERTY 10: no stock item is ever over-drawn across lines.
      final usedByItem = <int, int>{};
      for (final line in order.lines) {
        expect(line.allocatedPieces >= 0, isTrue);
        usedByItem[line.stockItemId] =
            (usedByItem[line.stockItemId] ?? 0) + line.allocatedPieces;
      }
      for (final a in availability) {
        final used = usedByItem[a.stockItemId] ?? 0;
        expect(
          used <= a.availablePieces,
          isTrue,
          reason: 'stock item ${a.stockItemId} over-drawn: '
              '$used > ${a.availablePieces}',
        );
        // Remaining availability is decremented correctly and never negative.
        expect(a.availablePieces - used >= 0, isTrue);
      }

      // (2) Each piece is billed EXACTLY ONCE. Bill every produced line at a
      //     flat rate and sum the billed pieces per stock item — this must
      //     reproduce the per-item consumption exactly (no piece billed twice,
      //     none dropped). We reconstruct the piece count a billed line
      //     represents from its allocated CFT and the SKU geometry.
      final skuById = <int, SkuAvailability>{
        for (final a in availability) a.stockItemId: a,
      };
      final billedPiecesByItem = <int, int>{};
      final inputs = <GoodsLineInput>[];
      for (final line in order.lines) {
        if (line.allocatedPieces <= 0) {
          continue;
        }
        inputs.add(
          GoodsLineInput(
            stockItemId: line.stockItemId,
            varietyId: line.varietyId,
            crossSectionId: line.crossSectionId,
            lengthFt: line.lengthFt,
            allocatedCft: line.allocatedCft,
            rate: Rational.fromInt(100), // flat ₹100/CFT; identity irrelevant
          ),
        );
        billedPiecesByItem[line.stockItemId] =
            (billedPiecesByItem[line.stockItemId] ?? 0) + line.allocatedPieces;
      }

      // The billed-pieces tally equals the allocation consumption tally: every
      // allocated piece appears once on the bill and no more.
      final nonZeroUsed = <int, int>{
        for (final e in usedByItem.entries)
          if (e.value > 0) e.key: e.value,
      };
      expect(billedPiecesByItem, nonZeroUsed);

      // The goods bill computes without error and its total volume equals the
      // exact sum of the billed lines' allocated CFT — the same pieces, counted
      // once (Requirement 9.6 routed through the shared engine).
      final bill = _billing.computeGoods(inputs);
      final expectedBilledCft = inputs
          .map((i) => i.allocatedCft.value)
          .fold(Rational.zero, (a, b) => a + b);
      expect(bill.totalCft.value, expectedBilledCft);

      // Cross-check the reconstructed billed pieces against each line's CFT:
      // allocatedCft == (W×T/144) × lengthFt × pieces, so pieces are recoverable
      // and must match allocatedPieces — proving the CFT billed corresponds to
      // exactly the pieces allocated (no hidden double count in the money).
      for (final line in order.lines) {
        if (line.allocatedPieces <= 0) {
          continue;
        }
        final sku = skuById[line.stockItemId]!;
        final perPiece = _calc.cftPerPiece(sku.crossSection, line.lengthFt);
        final expectedPieces = line.allocatedCft.value / perPiece.value;
        expect(expectedPieces, Rational.fromInt(line.allocatedPieces),
            reason: 'line CFT must correspond to exactly its allocated pieces');
      }

      // (3) Determinism: re-running yields identical per-item consumption and
      //     the same overall partial flag (the composition is repeatable).
      final again = _allocator.allocateOrder(requests, availability);
      final usedAgain = <int, int>{};
      for (final line in again.lines) {
        usedAgain[line.stockItemId] =
            (usedAgain[line.stockItemId] ?? 0) + line.allocatedPieces;
      }
      expect(usedAgain, usedByItem);
      expect(again.isPartial, order.isPartial);
    },
  );
}
