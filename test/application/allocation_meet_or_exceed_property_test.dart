// Property-based test for single-SKU target-CFT meet-or-exceed (task 9.1 /
// Property 6).
//
// Property 6 - Meet-or-exceed single-SKU unit count (design.md -> Correctness
// Properties; Requirements 7.6, 8.2):
//
//   For all positive target CFT values and positive per-sale-unit CFT values,
//   when stock is sufficient the allocated unit count for a single eligible
//   SKU equals `ceil(target_CFT / CFT_per_sale_unit)` using exact arithmetic,
//   and the resulting allocated CFT is the smallest whole-unit allocation that
//   is greater than or equal to the target.
//
// This drives `AllocationService.allocateTargetCftFixedLength` across many
// random reaper/plank cross-sections, lengths (2..9 ft), and exact rational
// targets with ample confirmed stock, and checks:
//   * allocatedUnits == ceil(target / unitCft) (exact BigInt, no double);
//   * allocatedCft >= target (meet-or-exceed holds);
//   * allocatedCft is the SMALLEST such whole-unit allocation — one fewer unit
//     is strictly below the target (minimality), unless the answer is a single
//     unit;
//   * billing uses the actual allocated CFT, equal to units × unit CFT.
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
    ExploreConfig(numRuns: 200, random: Random(20240911));

/// One randomly generated single-SKU target-CFT scenario at a fixed length.
class _Scenario {
  const _Scenario({
    required this.widthIn,
    required this.thicknessIn,
    required this.lengthFt,
    required this.isReaper,
    required this.targetNum,
    required this.targetDen,
  });

  final int widthIn;
  final int thicknessIn;
  final int lengthFt;
  final bool isReaper;

  /// Target CFT = targetNum / targetDen, strictly positive.
  final int targetNum;
  final int targetDen;

  @override
  String toString() =>
      '_Scenario(w: $widthIn, t: $thicknessIn, l: $lengthFt, '
      'reaper: $isReaper, target: $targetNum/$targetDen)';
}

final Generator<int> _widthIn = any.intInRange(1, 13); // 1..12 in
final Generator<int> _thicknessIn = any.intInRange(1, 7); // 1..6 in
final Generator<int> _lengthFt = any.intInRange(2, 10); // 2..9 ft inclusive
final Generator<int> _targetNum = any.intInRange(1, 2001); // 1..2000
final Generator<int> _targetDen = any.intInRange(1, 13); // 1..12

final Generator<_Scenario> _scenario = any
    .combine6(
      _widthIn,
      _thicknessIn,
      _lengthFt,
      any.bool,
      _targetNum,
      _targetDen,
      (int w, int t, int l, bool reaper, int tn, int td) => _Scenario(
        widthIn: w,
        thicknessIn: t,
        lengthFt: l,
        isReaper: reaper,
        targetNum: tn,
        targetDen: td,
      ),
    );

void main() {
  const calc = CalculationService();
  const service = AllocationService();

  Glados<_Scenario>(_scenario, _explore).test(
    'Feature: wood-cft-app, Property 6: Meet-or-exceed single-SKU unit count - '
    'allocated units = ceil(target / CFT_per_sale_unit) exactly, allocated CFT '
    '>= target and is the smallest such whole-unit allocation '
    '(Requirements 7.6, 8.2)',
    (_Scenario s) {
      final category =
          s.isReaper ? WoodCategory.reaper : WoodCategory.plank;
      final crossSection = CrossSection(
        id: 1,
        widthIn: s.widthIn,
        thicknessIn: s.thicknessIn,
        category: category,
      );
      final bunchSize = crossSection.bunchSize;
      final target =
          Rational(BigInt.from(s.targetNum), BigInt.from(s.targetDen));

      final request = TargetCftFixedLengthRequest(
        varietyId: 42,
        crossSectionId: crossSection.id,
        lengthFt: s.lengthFt,
        targetCft: target,
      );

      // Exact CFT of one whole sale unit at this length (bunch for a reaper,
      // piece for a plank).
      final unitCft = s.isReaper
          ? calc.cftPerBunch(crossSection, s.lengthFt)
          : calc.cftPerPiece(crossSection, s.lengthFt);

      // Expected count via exact rational ceil, computed independently.
      final expectedUnits = (target / unitCft.value).ceil().toInt();

      // Ample confirmed stock so the SKU is "sufficient": many more pieces than
      // the expected whole-unit requirement.
      final availablePieces = (expectedUnits + 10) * bunchSize;
      final availability = SkuAvailability(
        stockItemId: 7,
        crossSection: crossSection,
        lengthFt: s.lengthFt,
        availablePieces: availablePieces,
      );

      final line =
          service.allocateTargetCftFixedLength(request, availability);

      // Fully satisfied (sufficient stock), whole units of the right kind.
      expect(line.isPartial, isFalse);
      expect(
        line.unit,
        s.isReaper ? AllocationUnit.bunch : AllocationUnit.piece,
      );

      // Count equals the exact ceil of target / unit CFT.
      expect(line.allocatedUnits, expectedUnits);
      expect(line.allocatedPieces, expectedUnits * bunchSize);

      // Billing uses actual allocated CFT = units × unit CFT, exactly.
      expect(line.allocatedCft.value, unitCft.value * Rational.fromInt(expectedUnits));

      // Meet-or-exceed: allocated CFT is >= the target.
      expect(line.allocatedCft.value >= target, isTrue);

      // Smallest such whole-unit allocation: one fewer unit is strictly below
      // the target (only check when there is a smaller non-negative count).
      if (expectedUnits >= 1) {
        final oneFewer =
            unitCft.value * Rational.fromInt(expectedUnits - 1);
        expect(oneFewer < target, isTrue);
      }
    },
  );
}
