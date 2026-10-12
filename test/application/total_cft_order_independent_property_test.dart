// Property-based test for Property 3 (task 2.4).
//
// Property 3 - Total CFT is the exact order-independent sum of line CFT
// (design.md -> Correctness Properties; Requirements 2.5, 9.6):
//
//   "For all finite lists of allocated lines, the total CFT equals the sum of
//    the exact unrounded per-line CFT values, and the result is independent of
//    summation order (sum-of-exact equals exact-of-sum)."
//
// The test drives `CalculationService.totalCft` with random finite lists of
// line CFT values. Each line value is a genuine exact `Cft` built the way the
// production code does it: `CalculationService.lineCftFor(crossSection,
// lengthFt, pieceQty)` over randomly generated reaper/plank cross-sections,
// catalog lengths (2..9 ft), and whole quantities. This exercises the real
// engine path, not a hand-built fraction, so the property speaks to the values
// billing and exports actually sum.
//
// For every generated list it asserts, over >= 100 iterations:
//   1. sum-of-exact == exact-of-sum: `totalCft(lines)` equals an independently
//      accumulated exact `Rational` of the same lines (no rounding drift).
//   2. Order independence: shuffling and reversing the list yields the exact
//      same total (addition of exact rationals is commutative/associative, so
//      the engine must not depend on iteration order).
//   3. The empty list sums to exactly zero (additive identity).
//
// PBT framework: `package:glados`. `ExploreConfig(numRuns:, random:)` fixes the
// iteration count (>= 100) and seeds a deterministic `Random`, so any
// counterexample reproduces exactly. Glados re-exports `package:test`.
//
// Pure-Dart test: imports only the domain + application layers, `package:glados`,
// and `package:rational`. No Flutter widgets, no IO.

import 'dart:math' as math;

import 'package:glados/glados.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/cft.dart';

/// The single shared engine under test.
const CalculationService _calc = CalculationService();

/// Deterministic exploration config giving the property >= 100 iterations from
/// a fixed seed (so a failure reproduces exactly).
final ExploreConfig _explore =
    ExploreConfig(numRuns: 200, random: Random(20240607));

/// A randomly generated allocated line: a cross-section, a catalog length, and
/// a whole quantity. Its exact CFT is produced by the real engine.
class _Line {
  const _Line(this.widthIn, this.thicknessIn, this.isReaper, this.lengthFt,
      this.quantity);

  final int widthIn;
  final int thicknessIn;
  final bool isReaper;
  final int lengthFt;
  final int quantity;

  CrossSection get crossSection => CrossSection(
        id: 1,
        widthIn: widthIn,
        thicknessIn: thicknessIn,
        category: isReaper ? WoodCategory.reaper : WoodCategory.plank,
      );

  /// The exact per-line CFT via the shared engine (the value billing sums).
  Cft get lineCft => _calc.lineCftFor(crossSection, lengthFt, quantity);

  @override
  String toString() => '_Line(w: $widthIn, t: $thicknessIn, '
      'cat: ${isReaper ? 'reaper' : 'plank'}, l: $lengthFt, q: $quantity)';
}

/// Generator for one valid allocated line, constrained to the real input
/// space: width 1..12 in, thickness 1..6 in, length 2..9 ft (Requirement 1.10),
/// quantity 1..300 pieces.
final Generator<_Line> _lineGen = any.combine5(
  any.intInRange(1, 13), // widthIn 1..12
  any.intInRange(1, 7), // thicknessIn 1..6
  any.bool, // reaper vs plank
  any.intInRange(2, 10), // lengthFt 2..9
  any.intInRange(1, 301), // quantity 1..300
  _Line.new,
);

/// Generator for a finite list of 0..24 allocated lines (includes the empty
/// list, which must total exactly zero).
final Generator<List<_Line>> _linesGen = any.listWithLengthInRange(0, 25, _lineGen);

void main() {
  group('Total CFT exact order-independent sum (Property 3, glados)', () {
    Glados<List<_Line>>(_linesGen, _explore).test(
      'Feature: wood-cft-app, Property 3: Total CFT is the exact '
      'order-independent sum of line CFT - totalCft equals the exact unrounded '
      'sum of the per-line CFT and is identical under any summation order '
      '(Requirements 2.5, 9.6)',
      (List<_Line> lines) {
        final lineCfts = [for (final line in lines) line.lineCft];

        // (1) sum-of-exact == exact-of-sum: build the expected total as an
        // independent exact Rational accumulation, with no rounding anywhere.
        var expected = Rational.zero;
        for (final cft in lineCfts) {
          expected += cft.value;
        }
        final total = _calc.totalCft(lineCfts);
        expect(total.value, expected,
            reason: 'total must equal the exact unrounded sum of the lines');

        // (2) Order independence: a reversed order and a shuffled order (with a
        // seed derived from the input so it stays deterministic) must produce
        // the exact same total.
        final reversed = lineCfts.reversed.toList();
        expect(_calc.totalCft(reversed).value, total.value,
            reason: 'reversing the lines must not change the total');

        final shuffled = [...lineCfts]
          ..shuffle(math.Random(lineCfts.length * 31 + 7));
        expect(_calc.totalCft(shuffled).value, total.value,
            reason: 'shuffling the lines must not change the total');

        // (3) The empty list is the additive identity: exactly zero CFT.
        if (lineCfts.isEmpty) {
          expect(total, Cft.zero);
          expect(total.value, Rational.zero);
        }
      },
    );
  });
}
