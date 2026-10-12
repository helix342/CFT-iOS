/// The single shared CFT (cubic-feet) calculation engine (task 2.3).
///
/// This is **the one** CFT engine for the whole application. Receiving (CFT
/// display), stock views (available CFT), allocation (exact CFT per sale unit),
/// billing (line amounts, totals), and exports (snapshot values) all route
/// through here, so a preview, an invoice, a DOCX, and a WhatsApp message can
/// never disagree about a volume (design.md -> Components and Interfaces: the
/// shared `CalculationService`).
///
/// Every result is an exact [Cft] built from `package:rational`; there is no
/// binary `double` anywhere on this path, so no floating-point drift can creep
/// into pricing, allocation, or loading-tier comparisons (Requirements 2.1,
/// 2.2; design.md -> CFT and Currency Arithmetic).
///
/// The authoritative volume formula is:
///
/// ```text
/// CFT_per_piece = width_in × thickness_in × length_ft / 144
/// ```
///
/// The divisor is **144** (square inches per square foot × 12), **never 1728**
/// (Requirement 2.2). Scaling to a bunch or a line is exact integer
/// multiplication, and a total is the exact unrounded sum of its lines
/// (Requirements 2.3, 2.4, 2.5).
///
/// Architecture rule (design.md): this service is pure Dart. It MUST NOT import
/// `package:flutter/*` or `dart:io`, so it runs under `flutter test` on Windows
/// without an iPhone or simulator.
library;

import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/cft.dart';

/// The CFT divisor that converts cubic inches of a one-foot-length-unit slice
/// into cubic feet for the `W×T×L/144` formula (Requirement 2.2).
///
/// It is deliberately named and asserted against the forbidden `1728` value in
/// tests so a future refactor cannot silently switch to board-foot math.
const int kCftDivisor = 144;

/// The forbidden divisor that the CFT formula must never use (Requirement 2.2).
///
/// Exposed only so tests and reviewers can assert `kCftDivisor != kForbiddenCftDivisor`.
const int kForbiddenCftDivisor = 1728;

/// The single shared CFT engine (design.md -> Components and Interfaces).
///
/// All methods are pure and stateless; the class carries no mutable state, so a
/// single `const` instance can be shared freely across layers and providers.
class CalculationService {
  /// Creates the shared calculation service.
  const CalculationService();

  /// Exact CFT of a single piece of [crossSection] cut to [lengthFt] feet.
  ///
  /// Computes `width_in × thickness_in × length_ft / 144` as an exact rational
  /// (Requirements 2.1, 2.2). The width and thickness (inches) come from
  /// [crossSection]; [lengthFt] is in feet and the two units are never
  /// interchanged.
  ///
  /// Throws a [RangeError] when [lengthFt] falls outside the inclusive
  /// 2–9 ft stock range (Requirement 1.10); detailed input-rejection UI is a
  /// later task, but the engine refuses an out-of-range length here so no
  /// invalid volume can be produced.
  Cft cftPerPiece(CrossSection crossSection, int lengthFt) {
    _checkLengthFt(lengthFt);
    // width_in × thickness_in × length_ft is an exact integer numerator; the
    // divisor 144 is the exact denominator. No rounding, no double.
    final numerator =
        crossSection.widthIn * crossSection.thicknessIn * lengthFt;
    return Cft.fraction(numerator, kCftDivisor);
  }

  /// Exact CFT of one whole bunch of [crossSection] at [lengthFt] feet.
  ///
  /// A bunch is `CrossSection.bunchSize` pieces (10 for a reaper); the bunch
  /// CFT is `cftPerPiece × bunchSize` (Requirement 2.3). For a plank, whose
  /// bunch size is 1, this equals [cftPerPiece].
  Cft cftPerBunch(CrossSection crossSection, int lengthFt) =>
      cftPerPiece(crossSection, lengthFt).timesInt(crossSection.bunchSize);

  /// Exact CFT of a line of [pieceQty] pieces at [perPiece] CFT each.
  ///
  /// Line CFT = `CFT_per_piece × piece_quantity` (Requirement 2.4). The caller
  /// supplies the per-piece volume (usually from [cftPerPiece]) so a line can
  /// be measured without re-deriving dimensions.
  ///
  /// Throws an [ArgumentError] when [pieceQty] is not positive; a line must
  /// represent at least one piece (detailed quantity-rejection UI is a later
  /// task — this guard keeps the engine from fabricating zero/negative lines).
  Cft lineCft(Cft perPiece, int pieceQty) {
    _checkPositiveQuantity(pieceQty, 'pieceQty');
    return perPiece.timesInt(pieceQty);
  }

  /// Convenience: exact CFT of a line computed straight from the catalog.
  ///
  /// Equivalent to `lineCft(cftPerPiece(crossSection, lengthFt), pieceQty)`;
  /// provided so callers that have the [crossSection] and [lengthFt] in hand do
  /// not have to compose the two steps themselves. The length and quantity are
  /// validated exactly as in [cftPerPiece] and [lineCft].
  Cft lineCftFor(CrossSection crossSection, int lengthFt, int pieceQty) =>
      lineCft(cftPerPiece(crossSection, lengthFt), pieceQty);

  /// Exact, order-independent sum of the given line [lineCfts] (Requirement
  /// 2.5, 9.6).
  ///
  /// The total is accumulated as an exact rational, so it is the unrounded sum
  /// of the exact line values and is identical regardless of iteration order.
  /// An empty iterable sums to [Cft.zero].
  Cft totalCft(Iterable<Cft> lineCfts) {
    var total = Cft.zero;
    for (final line in lineCfts) {
      total += line;
    }
    return total;
  }

  /// The piece-equivalent of [bunchCount] whole bunches of [crossSection].
  ///
  /// Returns `bunchCount × CrossSection.bunchSize` — e.g. 3 reaper bunches
  /// (bunch size 10) is 30 pieces (Requirements 3.1, 3.4). Reapers display the
  /// equivalent piece count alongside the bunch count, and this is the single
  /// place that conversion is defined.
  ///
  /// Throws an [ArgumentError] when [bunchCount] is negative; zero bunches is a
  /// valid (empty) quantity and yields zero pieces.
  int pieceEquivalent(CrossSection crossSection, int bunchCount) {
    if (bunchCount < 0) {
      throw ArgumentError.value(
        bunchCount,
        'bunchCount',
        'bunch count must not be negative',
      );
    }
    return bunchCount * crossSection.bunchSize;
  }

  /// Validates that [lengthFt] is within the inclusive 2–9 ft stock range.
  void _checkLengthFt(int lengthFt) {
    if (lengthFt < kMinLengthFt || lengthFt > kMaxLengthFt) {
      throw RangeError.range(
        lengthFt,
        kMinLengthFt,
        kMaxLengthFt,
        'lengthFt',
        'length (feet) must be within $kMinLengthFt–$kMaxLengthFt inclusive',
      );
    }
  }

  /// Validates that a piece/line [quantity] is strictly positive.
  void _checkPositiveQuantity(int quantity, String name) {
    if (quantity <= 0) {
      throw ArgumentError.value(
        quantity,
        name,
        'quantity must be a positive whole number',
      );
    }
  }
}
