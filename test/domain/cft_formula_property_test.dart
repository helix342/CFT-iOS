// Property-based tests for the exact CFT formula and unit scaling (task 1.5).
//
// These exercise two of the design's Correctness Properties across many
// randomly generated valid inputs (>= 100 iterations each) rather than a
// handful of fixed examples:
//
//   * Property 1 - Exact CFT formula (design.md -> Correctness Properties;
//     Requirements 2.1, 2.2): CFT_per_piece equals the exact rational
//     (width_in x thickness_in x length_ft) / 144, using divisor 144 and
//     never 1728.
//   * Property 2 - Unit scaling (bunch and line) is exact multiplication
//     (Requirements 2.3, 2.4): line CFT equals CFT_per_piece x q exactly and
//     bunch CFT equals CFT_per_piece x 10 exactly.
//
// PBT framework: `package:glados` (property-based testing for Dart). Glados
// drives each property with generator-produced inputs and shrinks any
// counterexample. `ExploreConfig(numRuns: ...)` fixes the iteration count
// (>= 100) and seeds a deterministic `Random`, so the suite is repeatable.
//
// `CalculationService` (task 2.3) does not exist yet, so the W x T x L / 144
// formula is evaluated directly here against an independently constructed
// exact `Rational`. This validates the `Cft` arithmetic surface (exact
// fraction construction, `timesInt`, exact equality) that the shared engine
// will later build on. It deliberately does NOT create a CalculationService.
//
// Pure-Dart domain test: imports only the domain layer, `package:rational`,
// and `package:glados` (which re-exports `package:test`). No Flutter widgets.

import 'package:glados/glados.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/domain/cft.dart';

/// Deterministic exploration config giving each property >= 100 iterations
/// from a fixed seed (so a failure reproduces exactly).
final ExploreConfig _explore =
    ExploreConfig(numRuns: 200, random: Random(20240517));

/// Width in inches: a sensible timber range (1..12 in).
final Generator<int> _widthIn = any.intInRange(1, 13); // 1..12 inclusive
/// Thickness in inches: the second cross-section dimension (1..6 in).
final Generator<int> _thicknessIn = any.intInRange(1, 7); // 1..6 inclusive
/// Length in feet: the catalog range 2..9 ft inclusive (Requirement 1.10).
final Generator<int> _lengthFt = any.intInRange(2, 10); // 2..9 inclusive
/// Whole sale quantity (pieces or bunches): 1..200.
final Generator<int> _quantity = any.intInRange(1, 201); // 1..200 inclusive

/// One randomly generated valid piece plus a whole quantity, used by the
/// unit-scaling property.
class _Piece {
  const _Piece(this.widthIn, this.thicknessIn, this.lengthFt, this.quantity);

  final int widthIn;
  final int thicknessIn;
  final int lengthFt;
  final int quantity;

  @override
  String toString() =>
      '_Piece(w: $widthIn, t: $thicknessIn, l: $lengthFt, q: $quantity)';
}

/// Generator combining width/thickness/length/quantity into a [_Piece].
final Generator<_Piece> _piece = any.combine4(
  _widthIn,
  _thicknessIn,
  _lengthFt,
  _quantity,
  _Piece.new,
);

/// The formula under test, expressed through the `Cft` value object exactly as
/// `CalculationService` will later: CFT_per_piece = W x T x L / 144.
Cft cftPerPiece(int widthIn, int thicknessIn, int lengthFt) =>
    Cft.fraction(widthIn * thicknessIn * lengthFt, 144);

void main() {
  group('CFT formula and unit-scaling properties (glados)', () {
    // Property 1: Exact CFT formula.
    Glados3<int, int, int>(
      _widthIn,
      _thicknessIn,
      _lengthFt,
      _explore,
    ).test(
      'Feature: wood-cft-app, Property 1: Exact CFT formula - '
      'CFT_per_piece equals (width_in x thickness_in x length_ft)/144 '
      'using divisor 144, never 1728 (Requirements 2.1, 2.2)',
      (int widthIn, int thicknessIn, int lengthFt) {
        final product = widthIn * thicknessIn * lengthFt;
        final actual = cftPerPiece(widthIn, thicknessIn, lengthFt).value;

        // Exact expected value built independently of `Cft`: the product over
        // the literal divisor 144.
        final expected = Rational(BigInt.from(product), BigInt.from(144));
        expect(actual, expected);

        // Divisor must be 144, not 1728. The /144 result is exactly 12x the
        // /1728 result; for any positive product the two are never equal.
        final wrong1728 = Rational(BigInt.from(product), BigInt.from(1728));
        expect(actual == wrong1728, isFalse);
        expect(actual, wrong1728 * Rational.fromInt(12));
      },
    );

    // Property 2: Unit scaling (bunch and line) is exact multiplication.
    Glados<_Piece>(_piece, _explore).test(
      'Feature: wood-cft-app, Property 2: Unit scaling (bunch and line) is '
      'exact multiplication - line CFT = CFT_per_piece x q and bunch CFT = '
      'CFT_per_piece x 10, exactly (Requirements 2.3, 2.4)',
      (_Piece p) {
        final perPiece = cftPerPiece(p.widthIn, p.thicknessIn, p.lengthFt);

        // Line CFT = per-piece x q, exactly (Requirement 2.4).
        final lineCft = perPiece.timesInt(p.quantity);
        expect(lineCft.value, perPiece.value * Rational.fromInt(p.quantity));

        // Bunch CFT = per-piece x 10, exactly (Requirement 2.3).
        final bunchCft = perPiece.timesInt(10);
        expect(bunchCft.value, perPiece.value * Rational.fromInt(10));

        // Scaling is exact, not display-rounded: a line of q pieces equals q
        // independent per-piece additions (no accumulated drift).
        var summed = Cft.zero;
        for (var i = 0; i < p.quantity; i++) {
          summed = summed + perPiece;
        }
        expect(lineCft.value, summed.value);
      },
    );
  });
}
