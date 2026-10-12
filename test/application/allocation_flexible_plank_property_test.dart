// Property-based test for the flexible plank whole-piece min-excess fill
// (task 9.3 / Property 13).
//
// Property 13 - Flexible plank uses whole pieces with minimal meet-or-exceed
// excess (design.md -> Correctness Properties; Requirement 8.11):
//
//   For all flexible-length plank requests with sufficient stock, the
//   allocation uses whole pieces, is >= the target, and has the smallest excess
//   CFT achievable among whole-piece options, with ties resolved by lower
//   Length_Ft then lower StockItem identifier.
//
// This drives `AllocationService.allocateFlexiblePlank` across many random
// plank cross-sections, random per-length confirmed piece stock at lengths
// 2..9 ft, and random exact-rational targets, and checks (when stock suffices):
//   * every line is a whole number of pieces counted in AllocationUnit.piece
//     (Requirement 8.11 whole-unit rule for planks);
//   * the allocated CFT meets or exceeds the target (meet-or-exceed);
//   * the excess is minimal: a plank's per-piece CFT is W×T×L/144, so the
//     allocated CFT is proportional to the length-unit sum S = sum(pieces×len);
//     the result's S is the SMALLEST achievable sum >= thresholdUnits, so no
//     whole-piece option has a smaller (closer) meet-or-exceed CFT. We prove
//     minimality directly: reducing by the shortest allocated length would drop
//     below the threshold, and no reachable sum lies strictly between the
//     threshold and the chosen sum;
//   * the reaper 60/30/10 length-group shares are never applied (there is no
//     8/9 ft exclusion and no share split) — Requirement 8.10;
//   * the allocation is deterministic/repeatable (Requirement 8.12).
//
// PBT framework: `package:glados`. `ExploreConfig(numRuns: ...)` fixes the
// iteration count (>= 100) and seeds a deterministic `Random`, so a failure
// reproduces exactly.
//
// Pure-domain / headless: imports only the domain + application layers,
// `package:rational`, and `package:glados`. No Flutter widgets, no DB.

import 'package:glados/glados.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/allocation_service.dart';
import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/order_request.dart';

/// Deterministic exploration config giving the property >= 100 iterations from
/// a fixed seed.
final ExploreConfig _explore =
    ExploreConfig(numRuns: 200, random: Random(20240913));

/// One randomly generated flexible-plank scenario: a plank cross-section, a
/// target CFT, and whole-piece availability at each length 2..9 ft (0 = none).
class _Scenario {
  const _Scenario({
    required this.widthIn,
    required this.thicknessIn,
    required this.targetNum,
    required this.targetDen,
    required this.piecesByLength,
  });

  final int widthIn;
  final int thicknessIn;

  /// Target CFT = targetNum / targetDen, strictly positive.
  final int targetNum;
  final int targetDen;

  /// Available whole pieces at each length 2..9 ft (index 0 -> 2 ft, ...,
  /// index 7 -> 9 ft). 0 means no stock at that length.
  final List<int> piecesByLength;

  @override
  String toString() =>
      '_Scenario(w: $widthIn, t: $thicknessIn, target: $targetNum/$targetDen, '
      'pieces2to9: $piecesByLength)';
}

final Generator<int> _widthIn = any.intInRange(1, 13); // 1..12 in
final Generator<int> _thicknessIn = any.intInRange(1, 7); // 1..6 in
final Generator<int> _targetNum = any.intInRange(1, 201); // 1..200
final Generator<int> _targetDen = any.intInRange(1, 13); // 1..12
// Pieces per length 2..9 ft: 0..19 each (0 means no stock at that length).
final Generator<List<int>> _pieces =
    any.listWithLength(8, any.intInRange(0, 20));

final Generator<_Scenario> _scenario = any.combine5(
  _widthIn,
  _thicknessIn,
  _targetNum,
  _targetDen,
  _pieces,
  (int w, int t, int tn, int td, List<int> pieces) => _Scenario(
    widthIn: w,
    thicknessIn: t,
    targetNum: tn,
    targetDen: td,
    piecesByLength: pieces,
  ),
);

void main() {
  const calc = CalculationService();
  const service = AllocationService();

  Glados<_Scenario>(_scenario, _explore).test(
    'Feature: wood-cft-app, Property 13: Flexible plank uses whole pieces with '
    'minimal meet-or-exceed excess - with sufficient stock the allocation is '
    'whole pieces, >= the target, with the smallest achievable excess CFT and '
    'a lower-length/lower-id tie-break, never applying reaper 60/30/10 shares '
    '(Requirements 8.10, 8.11)',
    (_Scenario s) {
      final crossSection = CrossSection(
        id: 1,
        widthIn: s.widthIn,
        thicknessIn: s.thicknessIn,
        category: WoodCategory.plank,
      );
      final target =
          Rational(BigInt.from(s.targetNum), BigInt.from(s.targetDen));

      // Build per-length availability for 2..9 ft from the generated pieces.
      final availability = <SkuAvailability>[];
      for (var len = 2; len <= 9; len++) {
        final pieces = s.piecesByLength[len - 2];
        if (pieces <= 0) {
          continue;
        }
        availability.add(
          SkuAvailability(
            stockItemId: 100 + len,
            crossSection: crossSection,
            lengthFt: len,
            availablePieces: pieces,
          ),
        );
      }

      final request = TargetCftFlexCrossSectionRequest(
        varietyId: 42,
        crossSectionId: crossSection.id,
        targetCft: target,
      );

      final result = service.allocateFlexiblePlank(request, availability);

      // Repeatability: identical inputs → identical structural result.
      final again = service.allocateFlexiblePlank(request, availability);
      expect(result.allocatedCft, again.allocatedCft);
      expect(result.isPartial, again.isPartial);
      expect(result.lines.length, again.lines.length);

      // (1) Every line is a whole number of PIECES (plank whole-unit rule),
      // and the line CFT matches the shared engine. Also assert no reaper
      // bunch unit ever appears (Requirement 8.11 / 8.10).
      var allocatedUnits = 0;
      var summed = Rational.zero;
      for (final line in result.lines) {
        expect(line.unit, AllocationUnit.piece);
        expect(line.allocatedUnits > 0, isTrue);
        // For a plank, pieces == units (bunch size 1).
        expect(line.allocatedPieces, line.allocatedUnits);
        expect(
          line.allocatedCft,
          calc.lineCftFor(crossSection, line.lengthFt, line.allocatedPieces),
        );
        allocatedUnits += line.allocatedPieces * line.lengthFt;
        summed += line.allocatedCft.value;
      }

      // Allocated CFT is the exact sum of the lines (billing uses allocated).
      expect(result.allocatedCft.value, summed);

      // Lines are ordered lower length first (stable tie-breaker surface).
      for (var i = 1; i < result.lines.length; i++) {
        expect(
          result.lines[i - 1].lengthFt < result.lines[i].lengthFt,
          isTrue,
        );
      }

      // No line reuses more pieces than were available at its length.
      for (final line in result.lines) {
        final avail = s.piecesByLength[line.lengthFt - 2];
        expect(line.allocatedPieces <= avail, isTrue);
      }

      // thresholdUnits = ceil(target × 144 / (W×T)) — the fewest length-units
      // whose CFT reaches the target. maxUnits = all stock's length-units.
      final wt = BigInt.from(s.widthIn * s.thicknessIn);
      final thresholdUnits =
          (target * Rational(BigInt.from(144), wt)).ceil().toInt();
      var maxUnits = 0;
      for (var len = 2; len <= 9; len++) {
        maxUnits += len * s.piecesByLength[len - 2];
      }

      if (maxUnits >= thresholdUnits) {
        // Sufficient stock: the target must be met or exceeded (no partial).
        expect(result.isPartial, isFalse);
        expect(result.allocatedCft.value >= target, isTrue);

        // (2) MINIMAL EXCESS. Allocated CFT is proportional to the length-unit
        // sum `allocatedUnits`; the chosen sum must be the smallest reachable
        // value >= thresholdUnits. We prove minimality two ways:
        //   (a) the chosen sum is within one shortest-length step of the
        //       threshold — removing the shortest allocated length would fall
        //       below it, so there is no slack of a full piece; and
        //   (b) no SMALLER whole-piece sum in [thresholdUnits, allocatedUnits)
        //       is reachable from the available pieces (checked by a bounded
        //       reachability sweep identical in spirit to the allocator).
        expect(allocatedUnits >= thresholdUnits, isTrue);

        final shortestUsed = result.lines
            .map((l) => l.lengthFt)
            .fold<int>(9, (m, v) => v < m ? v : m);
        // Removing one shortest-length piece drops below the threshold → the
        // overshoot is strictly less than one shortest-length unit.
        expect(allocatedUnits - shortestUsed < thresholdUnits, isTrue);

        // (b) Bounded reachability: no achievable length-unit sum lies in
        // [thresholdUnits, allocatedUnits) given availability — i.e. the
        // allocator truly picked the minimum meet-or-exceed sum.
        final reachable = List<bool>.filled(allocatedUnits, false);
        reachable[0] = true;
        for (var len = 2; len <= 9; len++) {
          final avail = s.piecesByLength[len - 2];
          if (avail <= 0) {
            continue;
          }
          final usedCount = List<int>.filled(allocatedUnits, 0);
          for (var sum = len; sum < allocatedUnits; sum++) {
            if (reachable[sum]) {
              continue;
            }
            final prev = sum - len;
            if (reachable[prev] && usedCount[prev] < avail) {
              reachable[sum] = true;
              usedCount[sum] = usedCount[prev] + 1;
            }
          }
        }
        for (var sum = thresholdUnits; sum < allocatedUnits; sum++) {
          expect(reachable[sum], isFalse,
              reason: 'a smaller meet-or-exceed sum $sum was achievable');
        }
      } else {
        // Understock: honest partial using every available piece, with the
        // exact CFT shortage (never claimed fulfilled).
        expect(result.isPartial, isTrue);
        expect(result.allocatedCft.value < target, isTrue);
        expect(result.shortageCft.value, target - result.allocatedCft.value);
        expect(allocatedUnits, maxUnits); // all stock consumed
      }
    },
  );
}
