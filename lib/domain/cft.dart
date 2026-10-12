/// Pure-Dart exact-rational CFT (cubic feet) value object.
///
/// CFT is a correctness-critical measure that drives pricing, allocation, and
/// loading-tier comparisons, so it is stored as an **exact rational**
/// (big-integer numerator/denominator via `package:rational`) and **never** as
/// a binary `double`, which would accumulate floating-point drift
/// (Requirements 2.1, 2.2; design.md -> CFT and Currency Arithmetic).
///
/// This value object deliberately exposes only the exact-arithmetic surface
/// that later layers build on:
///
/// * exact multiplication (by an integer or a rational),
/// * exact addition,
/// * value equality / hash code and ordering, and
/// * a **display-only** 4-decimal-place formatter ([Cft.toFixed]).
///
/// The display formatter is strictly presentational: it NEVER mutates or
/// rounds the stored exact value (Requirements 2.6, 2.7; Correctness
/// Property 4).
///
/// Architecture rule (design.md): the domain layer has a strict inward
/// dependency direction and MUST NOT import `package:flutter/*` or `dart:io`.
library;

import 'package:meta/meta.dart';
import 'package:rational/rational.dart';

/// An exact cubic-feet (CFT) volume backed by a [Rational].
///
/// Instances are immutable; every arithmetic operation returns a new [Cft]
/// and leaves the operands unchanged.
///
/// The width/thickness/length / 144 formula itself lives in the shared
/// `CalculationService` (task 2.3), not here — this type is only the exact
/// value container and its arithmetic.
@immutable
class Cft implements Comparable<Cft> {
  /// Creates a [Cft] directly from an exact [Rational] [value].
  const Cft(this.value);

  /// Creates a [Cft] from an integer number of cubic feet.
  factory Cft.fromInt(int wholeCft) => Cft(Rational.fromInt(wholeCft));

  /// Creates a [Cft] from an exact fraction [numerator] / [denominator].
  ///
  /// Throws an [ArgumentError] when [denominator] is zero.
  factory Cft.fraction(int numerator, int denominator) {
    if (denominator == 0) {
      throw ArgumentError.value(
        denominator,
        'denominator',
        'CFT denominator must not be zero',
      );
    }
    return Cft(
      Rational(BigInt.from(numerator), BigInt.from(denominator)),
    );
  }

  /// A [Cft] of exactly zero, useful as an additive identity for sums.
  static final Cft zero = Cft(Rational.zero);

  /// The exact stored volume. Never rounded for storage or computation.
  final Rational value;

  /// Returns the exact sum of this volume and [other].
  Cft operator +(Cft other) => Cft(value + other.value);

  /// Returns this volume multiplied exactly by an integer [factor].
  ///
  /// Used for scaling a per-piece volume to a bunch (x10) or a line (x qty).
  Cft timesInt(int factor) => Cft(value * Rational.fromInt(factor));

  /// Returns this volume multiplied exactly by a [Rational] [factor].
  Cft timesRational(Rational factor) => Cft(value * factor);

  @override
  int compareTo(Cft other) => value.compareTo(other.value);

  /// Whether this volume is strictly less than [other] (exact comparison).
  bool operator <(Cft other) => value < other.value;

  /// Whether this volume is less than or equal to [other] (exact comparison).
  bool operator <=(Cft other) => value <= other.value;

  /// Whether this volume is strictly greater than [other] (exact comparison).
  bool operator >(Cft other) => value > other.value;

  /// Whether this volume is greater than or equal to [other]
  /// (exact comparison).
  bool operator >=(Cft other) => value >= other.value;

  /// Returns the display string for this volume at [fractionDigits] decimal
  /// places (default 4), rounding half away from zero for presentation only.
  ///
  /// This is purely cosmetic: it computes the rounded text from the stored
  /// exact [value] without ever changing it, so a displayed figure can never
  /// influence computation, allocation, or loading-tier comparisons
  /// (Requirements 2.6, 2.7).
  ///
  /// Throws an [ArgumentError] when [fractionDigits] is negative.
  String toFixed([int fractionDigits = 4]) {
    if (fractionDigits < 0) {
      throw ArgumentError.value(
        fractionDigits,
        'fractionDigits',
        'must not be negative',
      );
    }
    final scale = Rational(BigInt.from(10).pow(fractionDigits));
    // `Rational.round()` rounds half away from zero; CFT is non-negative in
    // this domain, so that is exactly half-up. The division/round happens on a
    // throwaway scaled copy and leaves `value` untouched.
    final scaled = (value * scale).round();
    final negative = scaled.isNegative;
    final digits = scaled.abs().toString().padLeft(fractionDigits + 1, '0');

    final String formatted;
    if (fractionDigits == 0) {
      formatted = digits;
    } else {
      final splitAt = digits.length - fractionDigits;
      final whole = digits.substring(0, splitAt);
      final fraction = digits.substring(splitAt);
      formatted = '$whole.$fraction';
    }
    return negative ? '-$formatted' : formatted;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Cft && value == other.value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Cft($value)';
}
