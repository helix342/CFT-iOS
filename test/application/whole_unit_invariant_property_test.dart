// Property-based test for the whole-unit invariant and piece-equivalence
// (task 2.5).
//
// This exercises the design's Correctness Property 5 across many randomly
// generated valid quantities (>= 100 iterations) rather than a handful of
// fixed examples:
//
//   * Property 5 - Whole-unit invariant for sale quantities (design.md ->
//     Correctness Properties; Requirements 3.1, 3.2, 3.3, 3.4, 8.8):
//     for all sale quantities, every reaper quantity is a whole multiple of
//     10 pieces (never loose pieces) and every plank quantity is a
//     non-negative whole number of pieces; a reaper quantity entered as N
//     bunches displays an equivalent piece count of N x 10.
//
// The single source of the bunch -> piece conversion is
// `CalculationService.pieceEquivalent(crossSection, bunchCount)` =
// `bunchCount x crossSection.bunchSize` (task 2.3), where a reaper's bunch
// size is 10 and a plank's is 1 (`WoodCategory.bunchSize`, task 2.1). The
// property therefore asserts the invariant directly on that engine method.
//
// PBT framework: `package:glados`. `ExploreConfig(numRuns: ...)` fixes the
// iteration count (>= 100) and seeds a deterministic `Random`, so a failure
// reproduces exactly. Pure-Dart test: imports only the domain + application
// layers and `package:glados` (which re-exports `package:test`). No widgets.

import 'package:glados/glados.dart';

import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/domain/catalog.dart';

/// Deterministic exploration config giving the property >= 100 iterations
/// from a fixed seed (so a failure reproduces exactly).
final ExploreConfig _explore =
    ExploreConfig(numRuns: 200, random: Random(20240621));

/// The shared CFT engine under test (stateless, so a single instance is fine).
const CalculationService _service = CalculationService();

/// A representative reaper cross-section (2 x 1 in, bunch size 10).
final CrossSection _reaper = CrossSection(
  id: 1,
  widthIn: 2,
  thicknessIn: 1,
  category: WoodCategory.reaper,
);

/// A representative plank cross-section (4 x 1 in, bunch size 1).
final CrossSection _plank = CrossSection(
  id: 2,
  widthIn: 4,
  thicknessIn: 1,
  category: WoodCategory.plank,
);

/// Width in inches: a sensible timber range (1..12 in), used to build random
/// cross-sections so the invariant is checked beyond the two fixed examples.
final Generator<int> _widthIn = any.intInRange(1, 13); // 1..12 inclusive
/// Thickness in inches: the second cross-section dimension (1..6 in).
final Generator<int> _thicknessIn = any.intInRange(1, 7); // 1..6 inclusive
/// Whole bunch/piece count entered for a sale quantity: 0..500. Zero is a
/// valid (empty) quantity and yields zero pieces.
final Generator<int> _count = any.intInRange(0, 501); // 0..500 inclusive

void main() {
  group('Whole-unit invariant and piece-equivalence (glados)', () {
    // Property 5: Whole-unit invariant for sale quantities.
    //
    // For each generated (width, thickness, count) the invariant is checked
    // for BOTH categories built on that cross-section, so a single run covers
    // the reaper (bunch size 10) and plank (bunch size 1) halves of the
    // property together.
    Glados3<int, int, int>(
      _widthIn,
      _thicknessIn,
      _count,
      _explore,
    ).test(
      'Feature: wood-cft-app, Property 5: Whole-unit invariant for sale '
      'quantities - every reaper quantity is a whole multiple of 10 pieces '
      '(never loose pieces) and every plank quantity is a non-negative whole '
      'number of pieces; a reaper entered as N bunches displays N x 10 pieces '
      '(Requirements 3.1, 3.2, 3.3, 3.4, 8.8)',
      (int widthIn, int thicknessIn, int count) {
        final reaper = CrossSection(
          id: 1,
          widthIn: widthIn,
          thicknessIn: thicknessIn,
          category: WoodCategory.reaper,
        );
        final plank = CrossSection(
          id: 2,
          widthIn: widthIn,
          thicknessIn: thicknessIn,
          category: WoodCategory.plank,
        );

        final reaperPieces = _service.pieceEquivalent(reaper, count);
        final plankPieces = _service.pieceEquivalent(plank, count);

        // Non-negative whole number of pieces for every category (3.2, 3.3).
        expect(reaperPieces, isNonNegative);
        expect(plankPieces, isNonNegative);

        // Reaper: whole multiple of 10 pieces, never loose pieces (3.1), and
        // a reaper entered as N bunches displays N x 10 pieces (3.4, 8.8).
        expect(reaper.bunchSize, 10);
        expect(reaperPieces % 10, 0);
        expect(reaperPieces, count * 10);

        // Plank: bunch size 1, so the piece-equivalent is the count itself —
        // a plain whole number of pieces (3.3).
        expect(plank.bunchSize, 1);
        expect(plankPieces, count);
      },
    );

    // Fixed-example anchors for the two seeded cross-sections, confirming the
    // generated-input property above lines up with the catalog's real reaper
    // (bunch size 10) and plank (bunch size 1).
    Glados<int>(_count, _explore).test(
      'Feature: wood-cft-app, Property 5: Whole-unit invariant for sale '
      'quantities - seeded reaper 2x1 yields N x 10 pieces and seeded plank '
      '4x1 yields N pieces (Requirements 3.1, 3.3, 3.4)',
      (int count) {
        final reaperPieces = _service.pieceEquivalent(_reaper, count);
        expect(reaperPieces, count * 10);
        expect(reaperPieces % 10, 0);

        final plankPieces = _service.pieceEquivalent(_plank, count);
        expect(plankPieces, count);
      },
    );
  });
}
