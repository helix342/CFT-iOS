// Property-based tests for the exact-rational CFT display formatter and the
// exact-before-rounding money line amount (task 1.6).
//
// Covers two design Correctness Properties:
//
//   * Property 4  — Display rounding never alters computation.
//   * Property 14 — Line amount is exact before half-up rounding (the
//                   line-amount portion only; the goods-subtotal sum of
//                   rounded lines is exercised later by the billing tasks).
//
// No property-based-testing package was present in the pubspec at
// implementation time (task 1.5 may add one concurrently), so these use a
// SEEDED `dart:math` `Random` generator so the runs are reproducible, each
// property driving a MINIMUM of 100 iterations. If a shared PBT library is
// later adopted, these can be ported to it one-for-one.
//
// Pure-Dart only: imports the domain layer and the `test` matchers exposed via
// flutter_test. No widgets are pumped.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/domain/cft.dart';
import 'package:wood_cft/domain/money.dart';

/// Minimum number of generated cases per property (design requires >= 100).
const int _iterations = 200;

void main() {
  // --- Generators -----------------------------------------------------------

  /// A random non-negative exact [Rational] built from a big-integer
  /// numerator over a positive denominator, so repeating decimals (e.g. x/3,
  /// x/18) are well represented — those are the cases where display rounding
  /// would differ from the exact value.
  Rational randomNonNegativeRational(Random rng) {
    final numerator = BigInt.from(rng.nextInt(1 << 32));
    // Denominator in [1, 5000]; small primes/odd factors create long
    // repeating expansions that stress the display formatter.
    final denominator = BigInt.from(rng.nextInt(5000) + 1);
    return Rational(numerator, denominator);
  }

  /// A random exact CFT rational scaled into a realistic volume band
  /// (roughly 0..~300 CFT) while still allowing arbitrary repeating fractions.
  Rational randomCftRational(Random rng) {
    final base = randomNonNegativeRational(rng);
    // Keep magnitudes workshop-realistic by taking the fractional-ish part.
    return base - Rational(base.truncate()) + Rational.fromInt(rng.nextInt(300));
  }

  /// A random positive INR/CFT rate as an exact rational with up to two
  /// decimal places (rates are entered as rupees, e.g. 1234.50 /CFT).
  Rational randomRate(Random rng) {
    // 1.00 .. 9999.99 rupees per CFT, exact to the paise.
    final hundredths = rng.nextInt(999999) + 1;
    return Rational(BigInt.from(hundredths), BigInt.from(100));
  }

  // --- Property 4 -----------------------------------------------------------

  // Feature: wood-cft-app, Property 4: Display rounding never alters
  // computation.
  test(
    'Feature: wood-cft-app, Property 4: Display rounding never alters '
    'computation',
    () {
      final rng = Random(0x4C4654); // fixed seed -> reproducible failures.

      for (var i = 0; i < _iterations; i++) {
        final exact = randomCftRational(rng);
        final cft = Cft(exact);

        // 1. toFixed() must NOT mutate the stored exact value, and arithmetic
        //    on the value is unchanged after formatting.
        final valueBefore = cft.value;
        final display = cft.toFixed(); // 4 dp display string.
        expect(
          cft.value,
          valueBefore,
          reason: 'toFixed must never change the stored exact value',
        );

        // Exact arithmetic computed from the value is identical whether or not
        // the display string was produced — i.e. display never feeds back.
        final doubledExact = (cft + cft).value;
        final _ = cft.toFixed(); // produce display again
        expect(
          (cft + cft).value,
          doubledExact,
          reason: 'exact arithmetic must be unaffected by display formatting',
        );

        // 2. The 4-dp display, re-parsed as a number, is the exact value
        //    rounded half-up to 1e-4 — never the other way around. Where the
        //    exact value has a non-terminating/>4dp expansion the displayed
        //    figure DIFFERS from the exact value, proving the display is a
        //    lossy projection that must not be used in computation.
        final scale = Rational(BigInt.from(10000));
        final expectedScaled = (exact * scale).round(); // half away from zero
        final displayedScaled = (Rational.parse(display) * scale).round();
        expect(
          displayedScaled,
          expectedScaled,
          reason: 'display must equal the exact value rounded half-up to 4dp',
        );

        // When the exact value is not representable in 4 dp, the displayed
        // value and the exact value are genuinely different numbers.
        final exactScaled = exact * scale;
        final isExactIn4dp = exactScaled == Rational(exactScaled.round());
        if (!isExactIn4dp) {
          expect(
            Rational.parse(display) == exact,
            isFalse,
            reason: 'a rounded display value must differ from the exact value',
          );
        }
      }
    },
  );

  // --- Property 14 (line-amount portion) ------------------------------------

  // Feature: wood-cft-app, Property 14: Line amount is exact before half-up
  // rounding to paise.
  test(
    'Feature: wood-cft-app, Property 14: Line amount is exact before half-up '
    'rounding to paise',
    () {
      final rng = Random(0x4D4F4E); // "MON" seed -> reproducible failures.

      // Independent reference half-up rounding of an exact rupee amount to
      // paise, derived straight from the definition (floor + 1 iff the paise
      // fraction is >= 1/2), so it does not reuse Money's own implementation.
      BigInt referencePaiseHalfUp(Rational exactRupees) {
        final exactPaise = exactRupees * Rational.fromInt(100);
        final floor = exactPaise.floor(); // BigInt in this package version.
        final fraction = exactPaise - Rational(floor);
        final half = Rational(BigInt.one, BigInt.from(2));
        return fraction >= half ? floor + BigInt.one : floor;
      }

      for (var i = 0; i < _iterations; i++) {
        final exactCft = randomCftRational(rng);
        final rate = randomRate(rng);

        // Pre-rounding line amount is the exact product exact_CFT x rate.
        final exactRupees = exactCft * rate;

        // Money.fromExactRupees must equal that exact product rounded HALF-UP
        // to paise, compared against the independent reference computation.
        final lineAmount = Money.fromExactRupees(exactRupees);
        final expectedPaise = referencePaiseHalfUp(exactRupees);

        expect(
          lineAmount.paise,
          expectedPaise,
          reason: 'line amount must be exact_CFT x rate rounded half-up to '
              'paise (exactCft=$exactCft, rate=$rate)',
        );

        // And the rounding error is strictly within half a paise of the exact
        // amount, confirming nearest-paise rounding (not truncation): the
        // stored paise is never more than 1/2 paise away from the exact value.
        final exactPaise = exactRupees * Rational.fromInt(100);
        final diff = (exactPaise - Rational(lineAmount.paise)).abs();
        expect(
          diff <= Rational(BigInt.one, BigInt.from(2)),
          isTrue,
          reason: 'rounded paise must be within half a paise of the exact '
              'amount (exactCft=$exactCft, rate=$rate)',
        );
      }
    },
  );
}
