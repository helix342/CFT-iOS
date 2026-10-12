// Pure-Dart unit tests for the exact-rational `Cft` value object (task 1.3).
//
// These tests pin the Requirement 21 worked display values and prove the
// 4-decimal-place formatter is display-only and never mutates the stored
// exact value (Requirements 2.1, 2.2, 2.6, 2.7; Correctness Property 4 intent).
// The dedicated property-based tests live in tasks 1.5 / 1.6.
//
// Imports only the pure-Dart domain layer and the `test` matchers exposed via
// flutter_test — no widgets are pumped.

import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/domain/cft.dart';

void main() {
  // Helper: CFT_per_piece = W x T x L / 144 (the divisor-144 formula itself
  // belongs to CalculationService in task 2.3; computed inline here only to
  // build the exact fixtures the display tests assert on).
  Cft perPiece(int widthIn, int thicknessIn, int lengthFt) =>
      Cft.fraction(widthIn * thicknessIn * lengthFt, 144);

  group('Cft exact construction and value', () {
    test('fraction keeps the exact rational value', () {
      expect(Cft.fraction(1, 12).value, Rational(BigInt.one, BigInt.from(12)));
    });

    test('fromInt is an exact whole number', () {
      expect(Cft.fromInt(2).value, Rational.fromInt(2));
    });

    test('zero is the exact additive identity', () {
      final sample = Cft.fraction(25, 18);
      expect(Cft.zero + sample, sample);
    });

    test('rejects a zero denominator', () {
      expect(() => Cft.fraction(1, 0), throwsArgumentError);
    });
  });

  group('Cft exact arithmetic', () {
    test('addition is exact', () {
      // 1/12 + 1/12 = 1/6
      final sum = Cft.fraction(1, 12) + Cft.fraction(1, 12);
      expect(sum.value, Rational(BigInt.one, BigInt.from(6)));
    });

    test('timesInt scales exactly (per-piece -> bunch of 10)', () {
      // (1/12) x 10 = 5/6  (Req 21.2)
      final bunch = perPiece(2, 1, 6).timesInt(10);
      expect(bunch.value, Rational(BigInt.from(5), BigInt.from(6)));
    });

    test('timesRational multiplies exactly', () {
      // (5/6) x 3 = 5/2
      final scaled = Cft.fraction(5, 6).timesRational(Rational.fromInt(3));
      expect(scaled.value, Rational(BigInt.from(5), BigInt.from(2)));
    });
  });

  group('Cft equality, hashCode and comparison', () {
    test('equal values are == and share a hashCode', () {
      final a = Cft.fraction(2, 4);
      final b = Cft.fraction(1, 2);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('comparison operators use the exact value', () {
      final small = Cft.fraction(1, 12);
      final large = Cft.fraction(5, 6);
      expect(small < large, isTrue);
      expect(large > small, isTrue);
      expect(small <= Cft.fraction(1, 12), isTrue);
      expect(large >= Cft.fraction(5, 6), isTrue);
      expect(small.compareTo(large), lessThan(0));
    });
  });

  group('Cft display formatter pins Requirement 21 (4 dp)', () {
    test('Req 21.1: 2x1 at 6 ft = 1/12 -> "0.0833"', () {
      expect(perPiece(2, 1, 6).toFixed(), '0.0833');
    });

    test('Req 21.2: one bunch 2x1 at 6 ft = 5/6 -> "0.8333"', () {
      expect(perPiece(2, 1, 6).timesInt(10).toFixed(), '0.8333');
    });

    test('Req 21.3: 5 bunches 2x1 at 2 ft = 25/18 -> "1.3889"', () {
      // (2x1x2/144) x 50 = 25/18
      final cft = perPiece(2, 1, 2).timesInt(50);
      expect(cft.value, Rational(BigInt.from(25), BigInt.from(18)));
      expect(cft.toFixed(), '1.3889');
    });

    test('Req 21.4: 12 pieces 3x1 at 8 ft = exactly 2 -> "2.0000"', () {
      final cft = perPiece(3, 1, 8).timesInt(12);
      expect(cft.value, Rational.fromInt(2));
      expect(cft.toFixed(), '2.0000');
    });
  });

  group('Cft display is display-only (Property 4 intent)', () {
    test('toFixed never mutates the stored exact value', () {
      // 25/18 = 1.38888... ; display rounds to 1.3889 but the stored value
      // must remain exactly 25/18.
      final cft = Cft.fraction(25, 18);
      final exactBefore = cft.value;

      final displayed = cft.toFixed();

      expect(displayed, '1.3889');
      // Stored value unchanged and still NOT equal to the rounded display.
      expect(cft.value, exactBefore);
      expect(cft.value, Rational(BigInt.from(25), BigInt.from(18)));
      expect(cft.value == Rational.parse('1.3889'), isFalse);
    });

    test('rounded display does not feed back into computation', () {
      // Summing exact 1/3 three times is exactly 1, even though each displays
      // as "0.3333"; a display-rounded path (0.3333 x 3) would give 0.9999.
      final third = Cft.fraction(1, 3);
      expect(third.toFixed(), '0.3333');

      final exactSum = third + third + third;
      expect(exactSum.value, Rational.one);
      expect(exactSum.toFixed(), '1.0000');
    });
  });
}
