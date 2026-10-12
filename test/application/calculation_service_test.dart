// Pure-Dart unit tests for the shared CalculationService / CFT engine (task 2.3).
//
// These pin the Requirement 21 worked examples that exercise the one shared
// engine every later layer depends on:
//   * 21.1  2×1 @ 6 ft           → 1/12 CFT per piece
//   * 21.2  one bunch 2×1 @ 6 ft → 5/6 CFT
//   * 21.3  5 bunches 2×1 @ 2 ft → 25/18 CFT
//   * 21.4  12 pieces 3×1 @ 8 ft → exactly 2.0 CFT
//   * 21.5  3 bunches Mahogany 2×1 @ 6 ft → 30 pieces and exactly 2.5 CFT
// plus the exact order-independent total-CFT sum (Requirement 2.5), the
// divisor-144 / never-1728 rule (Requirement 2.2), piece-equivalence for
// reaper bunches (Requirement 3.4), and the input-validation guards.
//
// Values are compared as exact rationals, never as doubles, so a result is
// only "equal" when it is bit-for-bit the exact fraction the spec requires.
//
// Imports only the pure-Dart domain + application layers and the `test`
// matchers exposed via flutter_test — no widgets are pumped.

import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/cft.dart';

void main() {
  const calc = CalculationService();

  // Catalog fixtures. 2×1 is a reaper (bunch of 10); 3×1 is a plank.
  final reaper2x1 = CrossSection(
    id: 1,
    widthIn: 2,
    thicknessIn: 1,
    category: WoodCategory.reaper,
  );
  final plank3x1 = CrossSection(
    id: 2,
    widthIn: 3,
    thicknessIn: 1,
    category: WoodCategory.plank,
  );

  group('cftPerPiece (Requirements 2.1, 2.2)', () {
    test('21.1: 2×1 at 6 ft is exactly 1/12 CFT', () {
      expect(calc.cftPerPiece(reaper2x1, 6), Cft.fraction(1, 12));
    });

    test('uses divisor 144 and never 1728', () {
      // 1 ft³ ought to be 12×12×1 at 1 ft... but the stock range starts at
      // 2 ft, so assert the formula directly: 12×12 @ 1-equivalent via 6×4.
      expect(kCftDivisor, 144);
      expect(kForbiddenCftDivisor, 1728);
      expect(kCftDivisor, isNot(kForbiddenCftDivisor));
      // 6×6 in @ 4 ft = 144/144 = exactly 1 CFT (would be 1/12 under /1728).
      final sixBySix = CrossSection(
        id: 99,
        widthIn: 6,
        thicknessIn: 6,
        category: WoodCategory.plank,
      );
      expect(calc.cftPerPiece(sixBySix, 4), Cft.fromInt(1));
    });

    test('rejects a length below 2 ft and above 9 ft', () {
      expect(() => calc.cftPerPiece(reaper2x1, 1), throwsRangeError);
      expect(() => calc.cftPerPiece(reaper2x1, 10), throwsRangeError);
    });

    test('accepts the inclusive 2 ft and 9 ft bounds', () {
      expect(calc.cftPerPiece(reaper2x1, 2), Cft.fraction(4, 144));
      expect(calc.cftPerPiece(reaper2x1, 9), Cft.fraction(18, 144));
    });
  });

  group('cftPerBunch (Requirement 2.3)', () {
    test('21.2: one bunch of 2×1 at 6 ft is exactly 5/6 CFT', () {
      expect(calc.cftPerBunch(reaper2x1, 6), Cft.fraction(5, 6));
    });

    test('a plank bunch (size 1) equals its per-piece CFT', () {
      expect(
        calc.cftPerBunch(plank3x1, 8),
        calc.cftPerPiece(plank3x1, 8),
      );
    });
  });

  group('lineCft (Requirement 2.4)', () {
    test('21.3: 5 bunches (50 pieces) of 2×1 at 2 ft is exactly 25/18 CFT', () {
      final perPiece = calc.cftPerPiece(reaper2x1, 2);
      expect(calc.lineCft(perPiece, 50), Cft.fraction(25, 18));
    });

    test('21.4: 12 pieces of 3×1 at 8 ft is exactly 2.0 CFT', () {
      final perPiece = calc.cftPerPiece(plank3x1, 8);
      final line = calc.lineCft(perPiece, 12);
      expect(line, Cft.fromInt(2));
      expect(line.value, Rational.fromInt(2));
      expect(line.toFixed(), '2.0000');
    });

    test('lineCftFor composes per-piece and quantity in one call', () {
      expect(calc.lineCftFor(reaper2x1, 2, 50), Cft.fraction(25, 18));
    });

    test('rejects non-positive piece quantities', () {
      final perPiece = calc.cftPerPiece(reaper2x1, 6);
      expect(() => calc.lineCft(perPiece, 0), throwsArgumentError);
      expect(() => calc.lineCft(perPiece, -3), throwsArgumentError);
    });
  });

  group('21.5: 3 bunches Mahogany 2×1 at 6 ft', () {
    test('reports 30 pieces and exactly 2.5 CFT', () {
      // 2×1 is a reaper, bunch size 10, so 3 bunches = 30 pieces.
      final pieces = calc.pieceEquivalent(reaper2x1, 3);
      expect(pieces, 30);

      // CFT = (5/6 per bunch) × 3 = 5/2 = exactly 2.5.
      final lineByBunch = calc.cftPerBunch(reaper2x1, 6).timesInt(3);
      expect(lineByBunch, Cft.fraction(5, 2));
      expect(lineByBunch, calc.lineCftFor(reaper2x1, 6, pieces));
      expect(lineByBunch.toFixed(), '2.5000');
    });
  });

  group('pieceEquivalent (Requirement 3.4)', () {
    test('reaper bunches scale by 10 pieces each', () {
      expect(calc.pieceEquivalent(reaper2x1, 1), 10);
      expect(calc.pieceEquivalent(reaper2x1, 5), 50);
    });

    test('zero bunches is zero pieces', () {
      expect(calc.pieceEquivalent(reaper2x1, 0), 0);
    });

    test('rejects a negative bunch count', () {
      expect(() => calc.pieceEquivalent(reaper2x1, -1), throwsArgumentError);
    });
  });

  group('totalCft (Requirement 2.5): exact order-independent sum', () {
    test('sums exact line CFT without rounding drift', () {
      final lines = <Cft>[
        calc.lineCftFor(reaper2x1, 6, 10), // 5/6
        calc.lineCftFor(reaper2x1, 2, 50), // 25/18
        calc.lineCftFor(plank3x1, 8, 12), // 2
      ];
      // 5/6 + 25/18 + 2 = 15/18 + 25/18 + 36/18 = 76/18 = 38/9.
      expect(calc.totalCft(lines), Cft.fraction(38, 9));
    });

    test('is identical under any iteration order', () {
      final lines = <Cft>[
        Cft.fraction(1, 12),
        Cft.fraction(5, 6),
        Cft.fraction(25, 18),
        Cft.fromInt(2),
      ];
      final forward = calc.totalCft(lines);
      final reversed = calc.totalCft(lines.reversed);
      expect(forward, reversed);
    });

    test('an empty line set totals exactly zero', () {
      expect(calc.totalCft(const <Cft>[]), Cft.zero);
    });
  });
}
