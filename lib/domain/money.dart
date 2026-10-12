/// Pure-Dart money value object stored as exact integer **paise**.
///
/// Money is correctness-critical: it drives line amounts, subtotals, tax, and
/// the payable total that appear on invoices. It is stored as an integer count
/// of **paise** (a [BigInt], 1 rupee = 100 paise) and **never** as a binary
/// `double`, which would accumulate floating-point drift and misprice bills
/// (Requirement 9; design.md -> CFT and Currency Arithmetic -> Currency).
///
/// This value object exposes exactly the surface the billing engine (task 10)
/// needs:
///
/// * construction from paise or from a rupees amount,
/// * `Money.fromExactRupees` — multiply an exact `Rational` rupee amount
///   (e.g. `exact_CFT x rate`) and round **half-up to the nearest paise**
///   (Requirements 9.1, 9.2),
/// * exact `+` addition,
/// * value equality / hash code and ordering, and
/// * `format` — a `₹`-prefixed string at 2 decimal places with **Indian digit
///   grouping** (lakh / crore, not thousands) (Requirement 9.5).
///
/// Architecture rule (design.md): the domain layer has a strict inward
/// dependency direction and MUST NOT import `package:flutter/*` or `dart:io`.
library;

import 'package:meta/meta.dart';
import 'package:rational/rational.dart';

/// An exact monetary amount backed by an integer number of [paise].
///
/// Instances are immutable; every arithmetic operation returns a new [Money]
/// and leaves the operands unchanged.
@immutable
class Money implements Comparable<Money> {
  /// Creates a [Money] directly from an integer number of [paise].
  const Money(this.paise);

  /// Creates a [Money] from an integer number of [paise] (`int` convenience).
  factory Money.fromPaise(int paise) => Money(BigInt.from(paise));

  /// Creates a [Money] from a whole number of [rupees] (exact, no rounding).
  factory Money.fromRupees(int rupees) =>
      Money(BigInt.from(rupees) * _paisePerRupee);

  /// Creates a [Money] from an **exact** rupee amount expressed as a
  /// [Rational], rounding **half-up** to the nearest paise.
  ///
  /// This is the authoritative line-amount rule: given the exact rupee value
  /// `exact_CFT x rate`, convert to paise (`x 100`) and round half-up so a
  /// value exactly on the half-paise boundary rounds **away from zero**
  /// (Requirements 9.1, 9.2; design.md Currency step 2).
  factory Money.fromExactRupees(Rational exactRupees) =>
      Money(_roundHalfUp(exactRupees * _paisePerRupeeRational));

  /// A [Money] of exactly zero, useful as an additive identity for sums.
  static final Money zero = Money(BigInt.zero);

  /// The exact amount in paise. 100 paise == 1 rupee. Never a binary float.
  final BigInt paise;

  static final BigInt _paisePerRupee = BigInt.from(100);
  static final Rational _paisePerRupeeRational = Rational.fromInt(100);

  /// Rounds an exact [paiseValue] rational to the nearest whole paise,
  /// half **away from zero** (half-up for the non-negative amounts the billing
  /// domain produces).
  ///
  /// Computed as `floor(abs) + (fractional >= 1/2 ? 1 : 0)` on the absolute
  /// value, then the sign is reapplied, so the half case always rounds away
  /// from zero rather than to even.
  static BigInt _roundHalfUp(Rational paiseValue) {
    final negative = paiseValue < Rational.zero;
    final abs = negative ? -paiseValue : paiseValue;
    // `Rational.floor()` returns a `BigInt` in this package version.
    final floor = abs.floor();
    final fraction = abs - Rational(floor);
    final rounded = fraction >= _half ? floor + BigInt.one : floor;
    return negative ? -rounded : rounded;
  }

  static final Rational _half = Rational(BigInt.one, BigInt.from(2));

  /// Returns the exact sum of this amount and [other].
  Money operator +(Money other) => Money(paise + other.paise);

  /// Returns the exact difference of this amount and [other].
  Money operator -(Money other) => Money(paise - other.paise);

  @override
  int compareTo(Money other) => paise.compareTo(other.paise);

  /// Whether this amount is strictly less than [other].
  bool operator <(Money other) => paise < other.paise;

  /// Whether this amount is less than or equal to [other].
  bool operator <=(Money other) => paise <= other.paise;

  /// Whether this amount is strictly greater than [other].
  bool operator >(Money other) => paise > other.paise;

  /// Whether this amount is greater than or equal to [other].
  bool operator >=(Money other) => paise >= other.paise;

  /// Returns the `₹`-prefixed INR display string at 2 decimal places with
  /// **Indian digit grouping** (e.g. `₹1,66,666.67`).
  ///
  /// Indian grouping places the first separator after the last three digits of
  /// the whole part and then every two digits (thousand, lakh, crore), unlike
  /// the Western every-three-digits convention (Requirement 9.5).
  String format() {
    final negative = paise.isNegative;
    final absPaise = negative ? -paise : paise;

    final rupees = absPaise ~/ _paisePerRupee;
    final paiseRemainder = absPaise % _paisePerRupee;

    final whole = _groupIndian(rupees.toString());
    final fraction = paiseRemainder.toString().padLeft(2, '0');

    return '${negative ? '-' : ''}\u20B9$whole.$fraction';
  }

  /// Groups the whole-rupee [digits] string using the Indian system:
  /// the rightmost three digits form the first group, then groups of two.
  static String _groupIndian(String digits) {
    if (digits.length <= 3) {
      return digits;
    }
    // Last three digits stay together; the remaining lead is split into
    // two-digit groups from the right.
    final lastThree = digits.substring(digits.length - 3);
    final lead = digits.substring(0, digits.length - 3);

    final buffer = StringBuffer();
    final remainder = lead.length % 2;
    if (remainder != 0) {
      buffer.write(lead.substring(0, remainder));
    }
    for (var i = remainder; i < lead.length; i += 2) {
      if (buffer.isNotEmpty) {
        buffer.write(',');
      }
      buffer.write(lead.substring(i, i + 2));
    }
    return '$buffer,$lastThree';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Money && paise == other.paise);

  @override
  int get hashCode => paise.hashCode;

  @override
  String toString() => 'Money($paise paise)';
}
