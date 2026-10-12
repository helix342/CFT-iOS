// Pure-Dart unit tests for the exact integer-paise `Money` value object
// (task 1.4).
//
// These tests pin the half-up-to-paise rounding boundaries, Indian digit
// grouping of the INR display (including a value past one lakh to prove the
// lakh grouping), and the Requirement 9.1 / 9.2 line-amount intent: an exact
// `exact_CFT x rate` rupee amount is rounded half-up to paise. The dedicated
// property-based tests (Property 14) live in task 1.6.
//
// Imports only the pure-Dart domain layer and the `test` matchers exposed via
// flutter_test -- no widgets are pumped.

import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/domain/money.dart';

void main() {
  group('Money construction', () {
    test('fromPaise stores the exact paise count', () {
      expect(Money.fromPaise(166667).paise, BigInt.from(166667));
    });

    test('fromRupees scales to paise exactly', () {
      expect(Money.fromRupees(100).paise, BigInt.from(10000));
    });

    test('zero is the additive identity', () {
      final sample = Money.fromPaise(12345);
      expect(Money.zero + sample, sample);
    });
  });

  group('Money.fromExactRupees rounds half-up to paise', () {
    test('exactly half a paise rounds up (0.005 -> 0.01)', () {
      // 1/200 rupee = 0.5 paise -> rounds to 1 paise.
      final m = Money.fromExactRupees(Rational(BigInt.one, BigInt.from(200)));
      expect(m.paise, BigInt.one);
    });

    test('just below half a paise rounds down', () {
      // 0.004999... rupee < 0.5 paise -> rounds to 0 paise.
      final m = Money.fromExactRupees(
        Rational(BigInt.from(49), BigInt.from(10000)),
      );
      expect(m.paise, BigInt.zero);
    });

    test('just above half a paise rounds up', () {
      // 0.00501 rupee > 0.5 paise -> rounds to 1 paise.
      final m = Money.fromExactRupees(
        Rational(BigInt.from(501), BigInt.from(100000)),
      );
      expect(m.paise, BigInt.one);
    });

    test('a boundary at the next paise (0.015 -> 0.02)', () {
      // 1.5 paise -> half-up -> 2 paise.
      final m = Money.fromExactRupees(Rational(BigInt.from(3), BigInt.from(200)));
      expect(m.paise, BigInt.two);
    });

    test('an exact amount is preserved with no rounding', () {
      // 12.34 rupees = 1234 paise exactly.
      final m = Money.fromExactRupees(
        Rational(BigInt.from(1234), BigInt.from(100)),
      );
      expect(m.paise, BigInt.from(1234));
    });
  });

  group('Money line-amount intent (Requirements 9.1, 9.2)', () {
    test('exact_CFT x rate = 5000/3 rupees rounds half-up to Rs 1,666.67', () {
      // The repeating value 1666.6666... rupees (5000/3) is the exact line
      // amount; half-up to paise gives 166667 paise = Rs 1,666.67.
      final exactRupees = Rational(BigInt.from(5000), BigInt.from(3));
      final line = Money.fromExactRupees(exactRupees);

      expect(line.paise, BigInt.from(166667));
      expect(line.format(), '\u20B91,666.67');
    });

    test('line amount from an exact Cft-style rational x per-CFT rate', () {
      // 25/6 CFT (50 pieces of 2x1 @ 6 ft = 50/12 CFT) x Rs 400/CFT
      //   = 25/6 * 400 = 10000/6 = 5000/3 rupees -> Rs 1,666.67.
      final exactCft = Rational(BigInt.from(25), BigInt.from(6));
      final ratePerCft = Rational.fromInt(400);
      final line = Money.fromExactRupees(exactCft * ratePerCft);

      expect(line.paise, BigInt.from(166667));
      expect(line.format(), '\u20B91,666.67');
    });

    test('goods subtotal sums independently rounded lines', () {
      // Two 5000/3-rupee lines each round to 166667 paise; the subtotal is the
      // sum of the rounded lines (design: authoritative figure), not a single
      // rounding of 10000/3.
      final line = Money.fromExactRupees(Rational(BigInt.from(5000), BigInt.from(3)));
      final subtotal = line + line;
      expect(subtotal.paise, BigInt.from(333334));
      expect(subtotal.format(), '\u20B93,333.34');
    });
  });

  group('Money INR formatting with Indian digit grouping', () {
    test('small amounts need no grouping', () {
      expect(Money.fromPaise(0).format(), '\u20B90.00');
      expect(Money.fromPaise(5).format(), '\u20B90.05');
      expect(Money.fromRupees(999).format(), '\u20B9999.00');
    });

    test('thousands get a single separator after three digits', () {
      expect(Money.fromRupees(1000).format(), '\u20B91,000.00');
      expect(Money.fromRupees(12345).format(), '\u20B912,345.00');
    });

    test('lakh grouping: value past one lakh groups by two then three', () {
      // 1,66,666.67 -- the hallmark Indian (lakh) grouping, not 166,666.67.
      expect(Money.fromPaise(16666667).format(), '\u20B91,66,666.67');
      expect(Money.fromRupees(100000).format(), '\u20B91,00,000.00');
    });

    test('crore grouping continues by twos', () {
      // 1,23,45,678.90
      expect(Money.fromPaise(123456789 * 10).format(), '\u20B91,23,45,678.90');
    });

    test('negative amounts keep the sign ahead of the symbol', () {
      expect((Money.zero - Money.fromRupees(1500)).format(), '-\u20B91,500.00');
    });
  });

  group('Money arithmetic, equality and comparison', () {
    test('addition and subtraction are exact in paise', () {
      final a = Money.fromPaise(166667);
      final b = Money.fromPaise(10000);
      expect((a + b).paise, BigInt.from(176667));
      expect((a - b).paise, BigInt.from(156667));
    });

    test('equal amounts are == and share a hashCode', () {
      final a = Money.fromRupees(1);
      final b = Money.fromPaise(100);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('comparison operators use the exact paise value', () {
      final small = Money.fromPaise(100);
      final large = Money.fromPaise(10000);
      expect(small < large, isTrue);
      expect(large > small, isTrue);
      expect(small <= Money.fromPaise(100), isTrue);
      expect(large >= Money.fromPaise(10000), isTrue);
      expect(small.compareTo(large), lessThan(0));
    });
  });
}
