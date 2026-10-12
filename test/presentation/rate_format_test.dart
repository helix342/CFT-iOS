/// Unit tests for the price-matrix rupee parse/format helpers (task 7.2).
///
/// Pins the exact-rational bridge between typed rupee text and the stored
/// ₹/CFT [Rational] (Req 4.1): parsing introduces no floating-point error and
/// display round-trips cleanly.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/presentation/settings/rate_format.dart';

void main() {
  group('parseRateInput', () {
    test('parses a whole-rupee amount exactly', () {
      expect(parseRateInput('150'), Rational(BigInt.from(150)));
    });

    test('parses two decimals as exact paise (no float drift)', () {
      expect(
        parseRateInput('150.75'),
        Rational(BigInt.from(15075), BigInt.from(100)),
      );
    });

    test('parses one decimal', () {
      expect(
        parseRateInput('150.5'),
        Rational(BigInt.from(1505), BigInt.from(10)),
      );
    });

    test('tolerates a leading ₹ and digit-group commas', () {
      expect(
        parseRateInput('₹1,250.75'),
        Rational(BigInt.from(125075), BigInt.from(100)),
      );
    });

    test('rejects empty input', () {
      expect(() => parseRateInput('   '), throwsA(isA<RateInputError>()));
    });

    test('rejects non-numeric input', () {
      expect(() => parseRateInput('abc'), throwsA(isA<RateInputError>()));
    });

    test('rejects more than two decimals', () {
      expect(() => parseRateInput('150.755'), throwsA(isA<RateInputError>()));
    });

    test('rejects zero', () {
      expect(() => parseRateInput('0'), throwsA(isA<RateInputError>()));
    });
  });

  group('formatRate', () {
    test('shows a whole rupee amount with no decimals', () {
      expect(formatRate(Rational(BigInt.from(150))), '150');
    });

    test('shows two decimals when present', () {
      expect(
        formatRate(Rational(BigInt.from(15075), BigInt.from(100))),
        '150.75',
      );
    });

    test('trims a trailing zero decimal', () {
      expect(
        formatRate(Rational(BigInt.from(1505), BigInt.from(10))),
        '150.5',
      );
    });

    test('round-trips a parsed value', () {
      expect(formatRate(parseRateInput('150.75')), '150.75');
    });
  });
}
