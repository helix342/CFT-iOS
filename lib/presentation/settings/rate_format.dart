/// Rupee rate parsing and display for the price-matrix grid (task 7.2).
///
/// A ₹/CFT rate is stored as an exact [Rational] (never a binary `double` —
/// design.md -> CFT and Currency Arithmetic; Req 4.1). The owner, however,
/// types and reads a plain rupee amount with up to two decimal places. These
/// helpers bridge the two WITHOUT introducing floating-point error:
///
///   * [parseRateInput] turns a typed rupee string (e.g. "150", "150.5",
///     "1,250.75") into an exact [Rational] by scaling an integer paise value,
///     so "150.75" becomes `15075/100` exactly — not `150.7499999…`.
///   * [formatRate] renders a stored [Rational] back as a rupee string with up
///     to two decimals, trimming a trailing ".00" / ".x0" so clean integer
///     rates read as "150" rather than "150.00".
///
/// The grid holds no price policy; it only parses what the owner types and
/// displays what `PricingService` returns.
library;

import 'package:rational/rational.dart';

/// Thrown by [parseRateInput] when the typed text is not a valid rupee amount.
class RateInputError implements Exception {
  /// Creates an error with a human-readable [message] for the grid to surface.
  const RateInputError(this.message);

  /// Why the input was rejected (shown to the owner).
  final String message;

  @override
  String toString() => 'RateInputError: $message';
}

final RegExp _rupeePattern = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$');

/// Parses a typed rupee [input] into an exact ₹/CFT [Rational].
///
/// Accepts an optional leading currency symbol, surrounding whitespace, and
/// Indian/Western digit-group commas, then requires a non-negative decimal with
/// at most two fractional digits. The value is built as `paise / 100` so the
/// result is EXACT (Req 4.1): "150.75" -> `15075/100`.
///
/// Throws a [RateInputError] when the text is empty, malformed, has more than
/// two decimals, or resolves to a non-positive amount (a ₹/CFT rate must be
/// strictly positive).
Rational parseRateInput(String input) {
  var text = input.trim();
  if (text.startsWith('₹')) {
    text = text.substring(1).trim();
  }
  text = text.replaceAll(',', '');

  if (text.isEmpty) {
    throw const RateInputError('Enter a rate in ₹ per CFT.');
  }

  final match = _rupeePattern.firstMatch(text);
  if (match == null) {
    throw const RateInputError(
      'Enter a valid amount with up to two decimals (e.g. 150 or 150.75).',
    );
  }

  final whole = match.group(1)!;
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  final paise = BigInt.parse('$whole$fraction');

  if (paise <= BigInt.zero) {
    throw const RateInputError('A ₹/CFT rate must be greater than zero.');
  }

  return Rational(paise, BigInt.from(100));
}

/// Formats an exact ₹/CFT [rate] as a rupee string with up to two decimals.
///
/// Rounds half-up to paise for display only (the stored [Rational] is never
/// mutated) and trims trailing zero decimals so "150" shows as `150` and
/// "150.50" as `150.5`. Returns the amount without a currency symbol so the
/// grid can place the ₹ glyph itself.
String formatRate(Rational rate) {
  final hundred = Rational(BigInt.from(100));
  // Round half-up to the nearest paise: floor(rate*100 + 1/2).
  final half = Rational(BigInt.one, BigInt.two);
  final paise = (rate * hundred + half).floor();

  final rupees = paise ~/ BigInt.from(100);
  final remainder = (paise % BigInt.from(100)).abs();

  if (remainder == BigInt.zero) {
    return '$rupees';
  }
  final frac = remainder.toString().padLeft(2, '0');
  // Trim a trailing zero: 150.50 -> 150.5 (but keep 150.05).
  if (frac.endsWith('0')) {
    return '$rupees.${frac[0]}';
  }
  return '$rupees.$frac';
}
