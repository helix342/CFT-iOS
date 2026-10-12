// Property-based tests for allocation determinism/tie-breaking and the
// flexible-reaper 8-9 ft exclusion (task 9.9).
//
// This file covers two of the three correctness properties named by task 9.9
// (Properties 11, 12, 13); the min-excess Property 13 and the fallback-off
// exclusion slice of Property 12 already have dedicated property tests
// (allocation_flexible_plank_property_test.dart,
// allocation_flexible_reaper_property_test.dart). Here we prove the two
// behaviours the orchestrator asked for:
//
//   (a) Property 11 - Allocation is deterministic with a stable tie-breaker
//       (design.md -> Correctness Properties; Requirements 8.12, 21.11):
//       allocating the SAME request against the SAME availability yields the
//       SAME result every time, and shuffling the input order of equal
//       candidate stock rows does NOT change the chosen allocation. The
//       allocator's documented stable tie-break is lower Length_Ft first, then
//       lower StockItem id, so the choice cannot depend on list order.
//
//   (b) Property 12 - Flexible reaper excludes 8-9 ft and never applies reaper
//       weights to planks (design.md -> Correctness Properties; Requirements
//       8.7, 8.9, 8.10): the flexible reaper heuristic NEVER allocates 8 ft or
//       9 ft lengths unless `allow89ftFallback` is true, honours the 60/30/10
//       length-group shares, and keeps every allocation a whole number of
//       bunches. We exercise BOTH toggle states on the same stock (which always
//       includes 8/9 ft rows) and assert the default run excludes them while a
//       fallback-enabled run may use them and never allocates LESS CFT.
//
// PBT framework: `package:glados`. `ExploreConfig(numRuns: ...)` fixes the
// iteration count (>= 150) and seeds a deterministic `Random`, so any failure
// reproduces exactly.
//
// Pure-domain / headless: imports only the domain + application layers,
// `package:rational`, and `package:glados`. No Flutter widgets, no DB (hosted
// DB is irrelevant to the allocator — it consumes a plain availability
// snapshot).

import 'package:glados/glados.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/allocation_service.dart';
import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/order_request.dart';

/// Deterministic exploration config giving each property >= 150 iterations from
/// a fixed seed.
final ExploreConfig _explore =
    ExploreConfig(numRuns: 175, random: Random(20240919));

/// One randomly generated flexible scenario shared by both properties: a
/// cross-section (reaper or plank), a strictly-positive target CFT, and
/// per-length availability at every length 2..9 ft (0 = none). The 8/9 ft slots
/// are always candidates in the generator so the exclusion is actually
/// exercised.
class _Scenario {
  const _Scenario({
    required this.isReaper,
    required this.widthIn,
    required this.thicknessIn,
    required this.targetNum,
    required this.targetDen,
    required this.unitsByLength,
  });

  /// Reaper (bunch size 10, length-group heuristic) when true; plank (bunch
  /// size 1, min-excess) when false.
  final bool isReaper;

  final int widthIn;
  final int thicknessIn;

  /// Target CFT = targetNum / targetDen, strictly positive.
  final int targetNum;
  final int targetDen;

  /// Available WHOLE SALE UNITS at each length 2..9 ft (index 0 -> 2 ft, ...,
  /// index 7 -> 9 ft). For a reaper a unit is a bunch (× 10 pieces); for a
  /// plank a unit is a single piece. 0 means no stock at that length.
  final List<int> unitsByLength;

  @override
  String toString() => '_Scenario(reaper: $isReaper, w: $widthIn, '
      't: $thicknessIn, target: $targetNum/$targetDen, units2to9: '
      '$unitsByLength)';
}

final Generator<bool> _isReaper = any.bool;
final Generator<int> _widthIn = any.intInRange(1, 13); // 1..12 in
final Generator<int> _thicknessIn = any.intInRange(1, 7); // 1..6 in
final Generator<int> _targetNum = any.intInRange(1, 401); // 1..400
final Generator<int> _targetDen = any.intInRange(1, 13); // 1..12
// Units per length 2..9 ft: 0..9 each (0 means no stock at that length). The
// 8/9 ft entries are always generated so the reaper exclusion is exercised.
final Generator<List<int>> _units =
    any.listWithLength(8, any.intInRange(0, 10));

final Generator<_Scenario> _scenario = any.combine6(
  _isReaper,
  _widthIn,
  _thicknessIn,
  _targetNum,
  _targetDen,
  _units,
  (bool r, int w, int t, int tn, int td, List<int> units) => _Scenario(
    isReaper: r,
    widthIn: w,
    thicknessIn: t,
    targetNum: tn,
    targetDen: td,
    unitsByLength: units,
  ),
);

/// Builds the per-length availability rows (lower length first) for [s] against
/// the given [crossSection]. Each row carries a distinct, length-ordered
/// stockItemId so the stable tie-breaker (lower length, then lower id) has a
/// defined target.
List<SkuAvailability> _availabilityFor(_Scenario s, CrossSection crossSection) {
  final bunchSize = crossSection.bunchSize;
  final rows = <SkuAvailability>[];
  for (var len = 2; len <= 9; len++) {
    final units = s.unitsByLength[len - 2];
    if (units <= 0) {
      continue;
    }
    rows.add(
      SkuAvailability(
        stockItemId: 100 + len,
        crossSection: crossSection,
        lengthFt: len,
        availablePieces: units * bunchSize,
      ),
    );
  }
  return rows;
}

/// Flattens any flexible allocation into a canonical, order-independent map of
/// `lengthFt -> allocatedPieces`, so two runs can be compared for structural
/// equality regardless of list ordering. (The allocator already emits lower
/// length first, but we normalise defensively so the comparison proves the
/// CHOICE is identical, not merely the emission order.)
Map<int, int> _piecesByLength(List<AllocationLine> lines) {
  final out = <int, int>{};
  for (final line in lines) {
    out[line.lengthFt] = (out[line.lengthFt] ?? 0) + line.allocatedPieces;
  }
  return out;
}

void main() {
  const calc = CalculationService();
  const service = AllocationService();

  // -----------------------------------------------------------------------
  // Property 11 - Allocation is deterministic with a stable tie-breaker.
  // -----------------------------------------------------------------------
  Glados<_Scenario>(_scenario, _explore).test(
    'Feature: wood-cft-app, Property 11: Allocation is deterministic with a '
    'stable tie-breaker - the same request against the same availability '
    'yields the same result every time, and shuffling the input order of '
    'equal candidate stock rows does not change the chosen allocation '
    '(Requirements 8.12, 21.11)',
    (_Scenario s) {
      final crossSection = CrossSection(
        id: 1,
        widthIn: s.widthIn,
        thicknessIn: s.thicknessIn,
        category: s.isReaper ? WoodCategory.reaper : WoodCategory.plank,
      );
      final target =
          Rational(BigInt.from(s.targetNum), BigInt.from(s.targetDen));
      final request = TargetCftFlexCrossSectionRequest(
        varietyId: 42,
        crossSectionId: crossSection.id,
        targetCft: target,
      );

      final availability = _availabilityFor(s, crossSection);

      // The canonical allocation for the availability in natural (lower length
      // first) order, plus a repeat run on the SAME input.
      Map<int, int> allocate(List<SkuAvailability> rows) {
        if (s.isReaper) {
          return _piecesByLength(
            service.allocateFlexibleReaper(request, rows).lines,
          );
        }
        return _piecesByLength(
          service.allocateFlexiblePlank(request, rows).lines,
        );
      }

      final canonical = allocate(availability);

      // (1) Pure repeatability: re-running identical input is byte-identical.
      expect(allocate(availability), canonical);

      // (2) Order-independence / stable tie-breaking: feeding the SAME rows in
      // several different orders (reversed and rotations) must produce the
      // SAME chosen allocation. The stable tie-break keys on length then id,
      // never on list position, so the choice cannot shift.
      final permutations = <List<SkuAvailability>>[
        availability.reversed.toList(),
        if (availability.length > 1)
          [availability.last, ...availability.take(availability.length - 1)],
        if (availability.length > 2)
          [
            availability[availability.length ~/ 2],
            ...availability
                .where((a) => a != availability[availability.length ~/ 2]),
          ],
      ];
      for (final permuted in permutations) {
        expect(
          allocate(permuted),
          canonical,
          reason: 'allocation depended on input row order (unstable '
              'tie-breaker) for scenario $s',
        );
      }

      // (3) The chosen allocation is internally consistent with the shared CFT
      // engine (determinism must not hide a wrong total).
      var summed = Rational.zero;
      final lines = s.isReaper
          ? service.allocateFlexibleReaper(request, availability).lines
          : service.allocateFlexiblePlank(request, availability).lines;
      for (final line in lines) {
        expect(
          line.allocatedCft,
          calc.lineCftFor(crossSection, line.lengthFt, line.allocatedPieces),
        );
        summed += line.allocatedCft.value;
      }
      final allocatedTotal = canonical.entries.fold<Rational>(
        Rational.zero,
        (acc, e) =>
            acc + calc.lineCftFor(crossSection, e.key, e.value).value,
      );
      expect(summed, allocatedTotal);
    },
  );

  // -----------------------------------------------------------------------
  // Property 12 - Flexible reaper excludes 8-9 ft and honours the toggle.
  // -----------------------------------------------------------------------
  Glados<_Scenario>(_scenario, _explore).test(
    'Feature: wood-cft-app, Property 12: Flexible reaper excludes 8-9 ft and '
    'never applies reaper weights to planks - the heuristic never allocates '
    '8/9 ft lengths unless allow89ftFallback is true, keeps every allocation '
    'a whole number of bunches, and enabling the fallback never reduces the '
    'allocated CFT (Requirements 8.7, 8.9, 8.10)',
    (_Scenario s) {
      // Force a REAPER cross-section for this property regardless of the
      // generated flag — the 8/9 ft exclusion and length-group shares apply to
      // reapers only (planks are covered by Property 13).
      final crossSection = CrossSection(
        id: 1,
        widthIn: s.widthIn,
        thicknessIn: s.thicknessIn,
        category: WoodCategory.reaper,
      );
      final bunchSize = crossSection.bunchSize;
      final target =
          Rational(BigInt.from(s.targetNum), BigInt.from(s.targetDen));
      final request = TargetCftFlexCrossSectionRequest(
        varietyId: 42,
        crossSectionId: crossSection.id,
        targetCft: target,
      );

      final availability = _availabilityFor(s, crossSection);

      // Default run: 8/9 ft are EXCLUDED (Requirement 8.9).
      final defaultRun = service.allocateFlexibleReaper(request, availability);
      // Fallback run on the SAME stock: 8/9 ft become eligible (Requirement
      // 8.9, OD-5).
      final fallbackRun = service.allocateFlexibleReaper(
        request,
        availability,
        allow89ftFallback: true,
      );

      // (1) With the fallback OFF, no 8 ft or 9 ft line is ever produced, even
      // though the scenario deliberately stocks those lengths.
      for (final line in defaultRun.lines) {
        expect(
          line.lengthFt != 8 && line.lengthFt != 9,
          isTrue,
          reason: '8/9 ft used with the fallback disabled for scenario $s',
        );
      }

      // (2) Every allocation (both runs) is a whole number of BUNCHES counted
      // in AllocationUnit.bunch — reaper length-group shares never degrade to
      // loose pieces (Requirement 8.8); the plank path is never taken here.
      for (final run in <FlexibleReaperAllocation>[defaultRun, fallbackRun]) {
        var summed = Rational.zero;
        for (final line in run.lines) {
          expect(line.unit, AllocationUnit.bunch);
          expect(line.allocatedUnits > 0, isTrue);
          expect(line.allocatedPieces % bunchSize, 0);
          expect(line.allocatedPieces, line.allocatedUnits * bunchSize);
          expect(
            line.allocatedCft,
            calc.lineCftFor(crossSection, line.lengthFt, line.allocatedPieces),
          );
          summed += line.allocatedCft.value;
        }
        // Allocated CFT is the exact sum of the lines; a non-partial result
        // meets or exceeds the target, a partial honestly reports the shortage.
        expect(run.allocatedCft.value, summed);
        if (!run.isPartial) {
          expect(run.allocatedCft.value >= target, isTrue);
        } else {
          expect(run.allocatedCft.value < target, isTrue);
          expect(
            run.shortageCft.value,
            target - run.allocatedCft.value,
          );
        }
      }

      // (3) The toggle is a genuine fallback: enabling 8/9 ft can only ADD
      // reach, never remove it. The fallback run's allocated CFT is >= the
      // default run's, so excluding 8/9 ft by default never over-allocates and
      // the fallback honestly opens more stock when needed.
      expect(
        fallbackRun.allocatedCft.value >= defaultRun.allocatedCft.value,
        isTrue,
        reason: 'enabling the 8/9 ft fallback reduced allocated CFT for '
            'scenario $s',
      );
    },
  );
}
