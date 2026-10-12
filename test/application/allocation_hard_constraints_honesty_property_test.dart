// Property-based tests for allocation hard constraints and allocation honesty
// (task 9.7 / Properties 7 & 8).
//
// Property 7 - Hard constraints are never violated (design.md -> Correctness
// Properties; Requirement 8.1):
//
//   For all order requests and stock snapshots, every line in the allocation
//   result respects all hard constraints: it uses only an allowed length and
//   cross-section/category, satisfies the whole-unit rule, and allocates no
//   more than the available stock for its stock item.
//
// Property 8 - Allocation honesty (design.md -> Correctness Properties;
// Requirements 8.3, 8.4):
//
//   For all order requests, the allocation is either fully satisfied or clearly
//   labeled partial with a shortage equal to `demand - allocated`; it is never
//   silently reduced and a partial result is never labeled fulfilled.
//
// Both properties are driven across many random MULTI-LINE orders built from a
// shared pool of random SKUs (reaper + plank cross-sections, each at a random
// length 2..9 ft with random confirmed pieces), using every per-request shape
// the allocator supports via `allocateOrder`: exact-quantity, fixed-length
// target-CFT, and flexible-cross-section target-CFT (reaper 60/30/10 and plank
// min-excess). Many lines are deliberately aimed at the same cross-section so
// stock is pressured and partials are common.
//
// For Property 7 each produced AllocationLine is checked to:
//   * draw from a stock item that actually exists in the snapshot, at the SAME
//     cross-section + length the snapshot records for it (allowed length and
//     cross-section/category only);
//   * never introduce a 2x1 reaper length-group exclusion violation (no 8-9 ft
//     reaper line unless the fallback is enabled) and never apply reaper
//     bunching to a plank;
//   * satisfy the whole-unit rule: reapers only in complete bunches of 10
//     pieces (allocatedPieces is a positive multiple of 10 and equals
//     allocatedUnits * 10), planks only in whole pieces;
//   * never exceed the confirmed available pieces of its stock item, summed
//     across all lines of the order (no invented stock).
//
// For Property 8 each line/result is checked to:
//   * be either fully allocated (isPartial == false) or a clearly-labeled
//     partial (isPartial == true) - the two are exact inverses, so a partial is
//     never also "fulfilled";
//   * on the exact-quantity path, carry an honest shortage equal to
//     demand - allocated in both units and pieces, with the allocated units
//     being exactly the whole units that fit (never silently reduced to look
//     fulfilled);
//   * on the fixed-length path, be partial exactly when the whole units that
//     fit cannot reach the meet-or-exceed required unit count, with a positive
//     unit/piece shortage;
//   * on the flexible paths, be partial exactly when the allocated CFT is below
//     the target, with the labeled CFT shortage equal to target - allocated and
//     the allocated CFT strictly below the target (an honest, not fulfilled,
//     partial);
//   * never report fulfilling more CFT than was actually allocated: the summed
//     line CFT equals the result's reported allocatedCft on the flexible paths.
//
// PBT framework: `package:glados`. `ExploreConfig(numRuns: ...)` fixes the
// iteration count (>= 100) and seeds a deterministic `Random`, so any failure
// reproduces exactly.
//
// Pure-domain / headless: imports only the domain + application layers,
// `package:rational`, and `package:glados`. No Flutter widgets, no DB (the
// hosted store is irrelevant here - the allocator consumes a plain confirmed
// availability snapshot).

import 'package:glados/glados.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/allocation_service.dart';
import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/order_request.dart';

/// Deterministic exploration config giving each property >= 100 iterations from
/// a fixed seed, so a failing case reproduces exactly.
final ExploreConfig _explore =
    ExploreConfig(numRuns: 200, random: Random(20240917));

/// The three structured request shapes exercised through [AllocationService
/// .allocateOrder].
enum _Shape { exactQty, fixedLength, flexCrossSection }

/// A single SKU in the shared pool: one of the fixed cross-sections, a length
/// 2..9 ft, and confirmed available pieces (possibly zero).
class _Sku {
  const _Sku({
    required this.crossSectionPick,
    required this.lengthIndex,
    required this.pieces,
  });

  /// 0 -> reaper 2x1, 1 -> plank 4x1, 2 -> plank 6x1. Fixed cross-sections so
  /// the whole-unit discipline (bunch 10 vs piece 1) is exercised directly.
  final int crossSectionPick;

  /// Length index 0..7 -> feet 2..9.
  final int lengthIndex;

  /// Confirmed available pieces (0..). For a reaper this need not be a whole
  /// multiple of 10 - the allocator floors to whole bunches, which is exactly
  /// the whole-unit behaviour under test.
  final int pieces;

  int get lengthFt => 2 + lengthIndex;
}

/// A single request line targeting the pool by shape + a stock index.
class _Line {
  const _Line({
    required this.shapeIndex,
    required this.stockIndex,
    required this.wantUnits,
    required this.targetNum,
  });

  /// Which of the three [_Shape]s this line uses (mod 3).
  final int shapeIndex;

  /// Which pool SKU this line aims at (mod pool size). For the flexible shape
  /// only the SKU's cross-section is used (lengths are chosen by the allocator).
  final int stockIndex;

  /// Whole sale units for an exact-quantity line (1..).
  final int wantUnits;

  /// Numerator (over a small denominator) of a target CFT (1..).
  final int targetNum;

  _Shape get shape => _Shape.values[shapeIndex % _Shape.values.length];
}

/// A whole random multi-line scenario: a non-empty SKU pool, an ordered list of
/// request lines, and whether the 8-9 ft reaper fallback is enabled.
class _Scenario {
  const _Scenario({
    required this.skus,
    required this.lines,
    required this.allow89,
  });

  final List<_Sku> skus;
  final List<_Line> lines;
  final bool allow89;

  @override
  String toString() => '_Scenario(skus: ${skus.length}, '
      'lines: ${lines.length}, allow89: $allow89)';
}

final Generator<_Sku> _skuGen = any.combine3(
  any.intInRange(0, 3), // cross-section pick 0..2
  any.intInRange(0, 8), // length index 0..7 -> 2..9 ft
  any.intInRange(0, 45), // pieces 0..44
  (int pick, int lenIdx, int pieces) =>
      _Sku(crossSectionPick: pick, lengthIndex: lenIdx, pieces: pieces),
);

final Generator<_Line> _lineGen = any.combine4(
  any.intInRange(0, 9), // shape index (reduced mod 3)
  any.intInRange(0, 60), // stock index (reduced mod pool size)
  any.intInRange(1, 9), // want units 1..8
  any.intInRange(1, 24), // target numerator 1..23
  (int shapeIndex, int stockIndex, int wantUnits, int targetNum) => _Line(
    shapeIndex: shapeIndex,
    stockIndex: stockIndex,
    wantUnits: wantUnits,
    targetNum: targetNum,
  ),
);

final Generator<_Scenario> _scenario = any.combine3(
  any.listWithLengthInRange(1, 7, _skuGen), // 1..6 pool SKUs
  any.listWithLengthInRange(1, 7, _lineGen), // 1..6 request lines
  any.bool, // allow 8-9 ft reaper fallback
  (List<_Sku> skus, List<_Line> lines, bool allow89) =>
      _Scenario(skus: skus, lines: lines, allow89: allow89),
);

void main() {
  const calc = CalculationService();
  const service = AllocationService();

  // Fixed cross-sections: a reaper 2x1 (bunch size 10) and two planks.
  final reaper2x1 = CrossSection(
    id: 1,
    widthIn: 2,
    thicknessIn: 1,
    category: WoodCategory.reaper,
  );
  final plank4x1 = CrossSection(
    id: 2,
    widthIn: 4,
    thicknessIn: 1,
    category: WoodCategory.plank,
  );
  final plank6x1 = CrossSection(
    id: 3,
    widthIn: 6,
    thicknessIn: 1,
    category: WoodCategory.plank,
  );
  CrossSection crossSectionFor(int pick) {
    switch (pick % 3) {
      case 0:
        return reaper2x1;
      case 1:
        return plank4x1;
      default:
        return plank6x1;
    }
  }

  /// Builds a de-duplicated confirmed availability snapshot (one row per
  /// cross-section+length SKU, each with a distinct stock-item id) and the
  /// ordered list of structured requests for a [_Scenario]. Returns null when
  /// the pool collapses to nothing.
  ({List<SkuAvailability> availability, List<OrderRequest> requests})? build(
    _Scenario s,
  ) {
    final byKey = <String, SkuAvailability>{};
    var nextId = 500;
    for (final sk in s.skus) {
      final cs = crossSectionFor(sk.crossSectionPick);
      final key = '${cs.id}:${sk.lengthFt}';
      if (byKey.containsKey(key)) {
        continue; // one row per SKU
      }
      byKey[key] = SkuAvailability(
        stockItemId: nextId++,
        crossSection: cs,
        lengthFt: sk.lengthFt,
        availablePieces: sk.pieces,
      );
    }
    final availability = byKey.values.toList();
    if (availability.isEmpty) {
      return null;
    }

    final requests = <OrderRequest>[];
    for (final ln in s.lines) {
      final sku = availability[ln.stockIndex % availability.length];
      final cs = sku.crossSection;
      switch (ln.shape) {
        case _Shape.exactQty:
          requests.add(
            ExactQtyRequest(
              varietyId: 42,
              crossSectionId: cs.id,
              lengthFt: sku.lengthFt,
              quantityUnits: ln.wantUnits,
            ),
          );
        case _Shape.fixedLength:
          requests.add(
            TargetCftFixedLengthRequest(
              varietyId: 42,
              crossSectionId: cs.id,
              lengthFt: sku.lengthFt,
              targetCft: Rational(BigInt.from(ln.targetNum), BigInt.from(4)),
            ),
          );
        case _Shape.flexCrossSection:
          requests.add(
            TargetCftFlexCrossSectionRequest(
              varietyId: 42,
              crossSectionId: cs.id,
              targetCft: Rational(BigInt.from(ln.targetNum), BigInt.from(4)),
            ),
          );
      }
    }
    return (availability: availability, requests: requests);
  }

  // ---------------------------------------------------------------------------
  // Property 7: Hard constraints are never violated.
  // ---------------------------------------------------------------------------
  Glados<_Scenario>(_scenario, _explore).test(
    'Feature: wood-cft-app, Property 7: Hard constraints are never violated - '
    'every allocation line uses an allowed length + cross-section/category, '
    'reapers appear only in whole bunches of 10 (never loose), planks only in '
    'whole pieces, and no stock item is ever over-drawn beyond its confirmed '
    'available pieces (Requirement 8.1)',
    (_Scenario s) {
      final built = build(s);
      if (built == null) {
        return;
      }
      final availability = built.availability;
      final requests = built.requests;

      final order = service.allocateOrder(
        requests,
        availability,
        allow89ftFallback: s.allow89,
      );

      // Snapshot each stock item's identity so we can validate every line
      // against the SKU it claims to draw from (allowed length + cross-section).
      final byId = <int, SkuAvailability>{
        for (final a in availability) a.stockItemId: a,
      };

      final usedByItem = <int, int>{};
      // Iterate per originating request so each line knows which shape produced
      // it: the 8-9 ft reaper exclusion is a hard constraint of the FLEXIBLE
      // reaper heuristic only - an exact-quantity or fixed-length request may
      // legitimately pin an 8 or 9 ft reaper SKU.
      for (final lr in order.lineResults) {
        final fromFlexible = lr.kind == OrderRequestKind.targetCftFlexCrossSection;
        for (final line in lr.lines) {
          // The line must draw from a real stock item in the snapshot.
          final src = byId[line.stockItemId];
          expect(
            src,
            isNotNull,
            reason: 'line draws from unknown stock item ${line.stockItemId}; '
                'line=$line',
          );
          final sku = src!;

          // ALLOWED LENGTH + CROSS-SECTION/CATEGORY: the line's length and
          // cross-section exactly match the SKU it draws from; the length is a
          // valid 2..9 ft stock length.
          expect(line.lengthFt, sku.lengthFt);
          expect(line.crossSectionId, sku.crossSection.id);
          expect(line.lengthFt >= kMinLengthFt, isTrue);
          expect(line.lengthFt <= kMaxLengthFt, isTrue);

          final category = sku.crossSection.category;
          final bunchSize = sku.crossSection.bunchSize;

          // The line's unit must match the SKU's category (bunch for reaper,
          // piece for plank) - reaper bunching is never applied to a plank and
          // vice versa.
          expect(line.unit, AllocationUnit.forCategory(category));

          // Allocated pieces/units are always non-negative and consistent: a
          // fully-shorted line (nothing fit, or an earlier line consumed the
          // stock) legitimately carries zero on BOTH, with zero CFT - an honest
          // empty line, not a hard-constraint violation (it draws no stock).
          // Only a POSITIVE line is subject to the whole-unit rules.
          expect(line.allocatedPieces >= 0, isTrue);
          expect(line.allocatedUnits >= 0, isTrue);
          if (line.allocatedPieces == 0) {
            expect(line.allocatedUnits, 0, reason: 'empty line: $line');
            expect(line.allocatedCft.value, Rational.zero,
                reason: 'empty line non-zero CFT: $line');
          } else if (category == WoodCategory.reaper) {
            // Reapers only in COMPLETE bunches of 10 - never loose pieces.
            expect(line.allocatedPieces % 10, 0, reason: 'reaper loose: $line');
            expect(line.allocatedPieces, line.allocatedUnits * 10,
                reason: 'reaper bunch mismatch: $line');
            // 8-9 ft reaper lengths are excluded by the FLEXIBLE reaper
            // heuristic unless the fallback is on (Requirement 8.9). A pinned
            // exact/fixed-length request may still name an 8/9 ft SKU.
            if (fromFlexible && !s.allow89) {
              expect(line.lengthFt <= 7, isTrue, reason: '8-9ft reaper: $line');
            }
          } else {
            // Planks only in whole pieces (bunch size 1): units == pieces.
            expect(bunchSize, 1);
            expect(line.allocatedPieces, line.allocatedUnits);
          }

          // The allocated CFT equals the shared engine's exact line CFT for the
          // whole pieces claimed - no invented or mismatched volume. (The
          // engine rejects a zero quantity, so only check positive lines; the
          // empty case already asserted zero CFT above.)
          if (line.allocatedPieces > 0) {
            expect(
              line.allocatedCft.value,
              calc
                  .lineCftFor(
                      sku.crossSection, line.lengthFt, line.allocatedPieces)
                  .value,
            );
          }

          usedByItem[line.stockItemId] =
              (usedByItem[line.stockItemId] ?? 0) + line.allocatedPieces;
        }
      }

      // STOCK AVAILABILITY: summed across the whole order, no stock item is
      // ever drawn beyond its confirmed available pieces (never exceeding
      // available confirmed stock).
      for (final a in availability) {
        final used = usedByItem[a.stockItemId] ?? 0;
        expect(
          used <= a.availablePieces,
          isTrue,
          reason: 'stock item ${a.stockItemId} over-drawn: '
              '$used > ${a.availablePieces} (cs=${a.crossSection.id} '
              'len=${a.lengthFt} allow89=${s.allow89})',
        );
      }
    },
  );

  // ---------------------------------------------------------------------------
  // Property 8: Allocation honesty (no silent reduction; partial labeled with
  // the real shortage; a partial is never labeled fulfilled).
  // ---------------------------------------------------------------------------
  Glados<_Scenario>(_scenario, _explore).test(
    'Feature: wood-cft-app, Property 8: Allocation honesty - each line is '
    'either fully satisfied or clearly labeled partial with shortage = demand '
    '- allocated; the request is never silently reduced, a partial is never '
    'labeled fulfilled, and the service never reports fulfilling more CFT than '
    'it actually allocated (Requirements 8.3, 8.4)',
    (_Scenario s) {
      final built = build(s);
      if (built == null) {
        return;
      }
      final availability = built.availability;
      final requests = built.requests;

      final byId = <int, SkuAvailability>{
        for (final a in availability) a.stockItemId: a,
      };

      final order = service.allocateOrder(
        requests,
        availability,
        allow89ftFallback: s.allow89,
      );

      // The order partial flag is the OR of its line flags: a partial order is
      // never silently presented as fulfilled.
      final anyLinePartial =
          order.lineResults.any((lr) => lr.isPartial);
      expect(order.isPartial, anyLinePartial);
      expect(order.isFullyAllocated, !order.isPartial);

      // Re-run the per-request allocators against the SAME remaining
      // availability the order used, so we can assert the honesty invariants
      // shape-by-shape with an independent view of what was actually fit.
      final remaining = <int, int>{
        for (final a in availability) a.stockItemId: a.availablePieces,
      };

      for (final lr in order.lineResults) {
        final request = requests[lr.requestIndex];

        // partial and fully-allocated are exact inverses on every line - a
        // partial can never also be reported fulfilled.
        expect(lr.isFullyAllocated, !lr.isPartial);

        switch (request) {
          case ExactQtyRequest():
            final line = lr.lines.single;
            final sku = byId[line.stockItemId];
            final bunchSize = sku == null ? 1 : sku.crossSection.bunchSize;
            final avail = sku == null ? 0 : (remaining[sku.stockItemId] ?? 0);
            final demandUnits = request.quantityUnits;
            final fitUnits = sku == null ? 0 : (avail ~/ bunchSize);
            final expectFull = fitUnits >= demandUnits;

            expect(line.isPartial, !expectFull);
            if (expectFull) {
              // Fully satisfied: allocated exactly the demand, zero shortage.
              expect(line.allocatedUnits, demandUnits);
              expect(line.shortageUnits, 0);
              expect(line.shortagePieces, 0);
            } else {
              // Honest partial: allocated exactly the whole units that fit
              // (NEVER silently reduced to fake a fulfilled line), and the
              // shortage equals demand - allocated in both units and pieces.
              expect(line.allocatedUnits, fitUnits);
              expect(line.shortageUnits, demandUnits - fitUnits);
              expect(
                line.shortagePieces,
                (demandUnits - fitUnits) * bunchSize,
              );
              expect(line.shortageUnits > 0, isTrue);
            }

          case TargetCftFixedLengthRequest():
            final line = lr.lines.single;
            final sku = byId[line.stockItemId];
            if (sku != null) {
              final unitCft =
                  sku.crossSection.category == WoodCategory.reaper
                      ? calc.cftPerBunch(sku.crossSection, sku.lengthFt)
                      : calc.cftPerPiece(sku.crossSection, sku.lengthFt);
              final requiredUnits =
                  (request.targetCft / unitCft.value).ceil().toInt();
              final fitUnits =
                  (remaining[sku.stockItemId] ?? 0) ~/ sku.crossSection.bunchSize;
              final expectFull = fitUnits >= requiredUnits;

              expect(line.isPartial, !expectFull);
              if (expectFull) {
                // Met-or-exceeded with zero shortage; billed on actual CFT.
                expect(line.allocatedUnits, requiredUnits);
                expect(line.shortageUnits, 0);
                expect(line.allocatedCft.value >= request.targetCft, isTrue);
              } else {
                // Honest partial: exactly the units that fit, positive shortage
                // = required - allocatable, never silently mixed/reduced.
                expect(line.allocatedUnits, fitUnits);
                expect(line.shortageUnits, requiredUnits - fitUnits);
                expect(line.shortageUnits > 0, isTrue);
              }
            }

          case TargetCftFlexCrossSectionRequest():
            final target = request.targetCft;
            final reaperResult = lr.flexibleReaper;
            final plankResult = lr.flexiblePlank;
            // Exactly one flexible summary is attached, matching the category.
            expect(
              (reaperResult == null) != (plankResult == null),
              isTrue,
              reason: 'flexible line must carry exactly one summary',
            );

            final lines = lr.lines;
            final isPartial =
                reaperResult?.isPartial ?? plankResult!.isPartial;
            final allocatedCft =
                reaperResult?.allocatedCft ?? plankResult!.allocatedCft;
            final shortageCft =
                reaperResult?.shortageCft ?? plankResult!.shortageCft;

            // NEVER report fulfilling more than actually allocated: the summary
            // allocatedCft equals the exact sum of its own line CFTs.
            final summed = calc.totalCft(lines.map((l) => l.allocatedCft));
            expect(allocatedCft.value, summed.value);

            if (isPartial) {
              // Honest partial: allocated strictly below the target and the
              // labeled shortage is exactly target - allocated (never fulfilled).
              expect(allocatedCft.value < target, isTrue);
              expect(shortageCft.value, target - allocatedCft.value);
              expect(shortageCft.value > Rational.zero, isTrue);
            } else {
              // Fully satisfied: met-or-exceeded with zero labeled shortage.
              expect(allocatedCft.value >= target, isTrue);
              expect(shortageCft.value, Rational.zero);
            }

          case TargetCftFlexCategoryRequest():
            // Not produced by build() (allocateOrder does not support it).
            break;
        }

        // Consume this line's pieces from the working remaining copy so the
        // next line's expectations see what earlier lines left (mirrors the
        // allocator's own remaining-availability bookkeeping).
        for (final line in lr.lines) {
          final id = line.stockItemId;
          if (id < 0 || line.allocatedPieces <= 0) {
            continue;
          }
          final left = remaining[id];
          if (left == null) {
            continue;
          }
          remaining[id] = left - line.allocatedPieces;
        }
      }
    },
  );
}
