// Property-based test for the flexible reaper length-share heuristic (task
// 9.2 / Property 12).
//
// Property 12 - Flexible reaper excludes 8-9 ft and never applies reaper
// weights to planks (design.md -> Correctness Properties; Requirements 8.9,
// 8.10):
//
//   For all flexible reaper requests with the 8-9 ft fallback DISABLED, no 8 ft
//   or 9 ft length is used and every allocation is a whole number of bunches.
//
// This drives `AllocationService.allocateFlexibleReaper` across many random
// reaper cross-sections, random per-length confirmed stock (deliberately
// INCLUDING 8 ft and 9 ft stock so the exclusion is actually exercised), and
// random exact-rational targets, and checks, with the fallback off:
//   * no allocation line is at 8 ft or 9 ft (Requirement 8.9);
//   * every line is a whole number of bunches — allocatedPieces is a multiple
//     of the bunch size and equals allocatedUnits × bunch size (Requirement
//     8.8 whole-unit invariant);
//   * the allocated CFT equals the exact sum of the line CFTs, and a non-
//     partial result meets or exceeds the target (billing uses allocated CFT).
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
    ExploreConfig(numRuns: 200, random: Random(20240912));

/// One randomly generated flexible-reaper scenario: a reaper cross-section, a
/// target CFT, and whole-bunch availability at each length 2..9 ft (0 = none).
class _Scenario {
  const _Scenario({
    required this.widthIn,
    required this.thicknessIn,
    required this.targetNum,
    required this.targetDen,
    required this.bunchesByLength,
  });

  final int widthIn;
  final int thicknessIn;

  /// Target CFT = targetNum / targetDen, strictly positive.
  final int targetNum;
  final int targetDen;

  /// Available whole bunches at each length 2..9 ft (index 0 -> 2 ft, ... index
  /// 7 -> 9 ft). Includes 8/9 ft stock so the exclusion is exercised.
  final List<int> bunchesByLength;

  @override
  String toString() =>
      '_Scenario(w: $widthIn, t: $thicknessIn, target: $targetNum/$targetDen, '
      'bunches2to9: $bunchesByLength)';
}

final Generator<int> _widthIn = any.intInRange(1, 13); // 1..12 in
final Generator<int> _thicknessIn = any.intInRange(1, 7); // 1..6 in
final Generator<int> _targetNum = any.intInRange(1, 501); // 1..500
final Generator<int> _targetDen = any.intInRange(1, 13); // 1..12
// Bunches per length 2..9 ft: 0..9 each (0 means no stock at that length).
final Generator<List<int>> _bunches =
    any.listWithLength(8, any.intInRange(0, 10));

final Generator<_Scenario> _scenario = any
    .combine5(
      _widthIn,
      _thicknessIn,
      _targetNum,
      _targetDen,
      _bunches,
      (int w, int t, int tn, int td, List<int> bunches) => _Scenario(
        widthIn: w,
        thicknessIn: t,
        targetNum: tn,
        targetDen: td,
        bunchesByLength: bunches,
      ),
    );

void main() {
  const calc = CalculationService();
  const service = AllocationService();

  Glados<_Scenario>(_scenario, _explore).test(
    'Feature: wood-cft-app, Property 12: Flexible reaper excludes 8-9 ft and '
    'never applies reaper weights to planks - with the fallback disabled no '
    '8/9 ft length is used and every allocation is a whole number of bunches '
    '(Requirements 8.9, 8.10)',
    (_Scenario s) {
      final crossSection = CrossSection(
        id: 1,
        widthIn: s.widthIn,
        thicknessIn: s.thicknessIn,
        category: WoodCategory.reaper,
      );
      final bunchSize = crossSection.bunchSize;
      final target =
          Rational(BigInt.from(s.targetNum), BigInt.from(s.targetDen));

      // Build per-length availability for 2..9 ft from the generated bunches.
      final availability = <SkuAvailability>[];
      for (var len = 2; len <= 9; len++) {
        final bunches = s.bunchesByLength[len - 2];
        if (bunches <= 0) {
          continue;
        }
        availability.add(
          SkuAvailability(
            stockItemId: 100 + len,
            crossSection: crossSection,
            lengthFt: len,
            availablePieces: bunches * bunchSize,
          ),
        );
      }

      final request = TargetCftFlexCrossSectionRequest(
        varietyId: 42,
        crossSectionId: crossSection.id,
        targetCft: target,
      );

      // Fallback DISABLED (the default): 8-9 ft must be excluded.
      final result = service.allocateFlexibleReaper(request, availability);

      // (1) No 8 ft or 9 ft length is ever used (Requirement 8.9).
      for (final line in result.lines) {
        expect(line.lengthFt == 8, isFalse);
        expect(line.lengthFt == 9, isFalse);
      }

      // (2) Every allocation is a whole number of bunches (Requirement 8.8).
      var summed = Rational.zero;
      for (final line in result.lines) {
        expect(line.unit, AllocationUnit.bunch);
        expect(line.allocatedUnits > 0, isTrue);
        expect(line.allocatedPieces % bunchSize, 0);
        expect(line.allocatedPieces, line.allocatedUnits * bunchSize);
        // The line CFT matches the shared engine for the allocated pieces.
        expect(
          line.allocatedCft,
          calc.lineCftFor(crossSection, line.lengthFt, line.allocatedPieces),
        );
        summed += line.allocatedCft.value;
      }

      // (3) Allocated CFT is the exact sum of the lines; a non-partial result
      // meets or exceeds the target (billing uses allocated CFT).
      expect(result.allocatedCft.value, summed);
      if (!result.isPartial) {
        expect(result.allocatedCft.value >= target, isTrue);
      } else {
        // A partial honestly reports the exact remaining shortage.
        expect(result.shortageCft.value, target - result.allocatedCft.value);
        expect(result.allocatedCft.value < target, isTrue);
      }
    },
  );
}
