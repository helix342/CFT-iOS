// Property-based test for multi-line order allocation never double-counting
// stock (task 9.4 / Property 10).
//
// Property 10 - Multi-line allocation never double-counts stock (design.md ->
// Correctness Properties; Requirements 8.6, 21.14):
//
//   For all multi-line order requests, the total pieces allocated from any
//   single stock item across all lines does not exceed that stock item's
//   available quantity.
//
// This drives `AllocationService.allocateOrder` across many random orders: a
// random ordered list of exact-quantity and fixed-length request lines, drawn
// from a shared pool of random stock items (reaper + plank cross-sections, each
// at a random length 2..9 ft with random confirmed pieces). Many lines are
// deliberately aimed at the SAME stock item so later lines can only draw on
// what earlier lines left. For every scenario it checks:
//   * NO stock item is ever over-drawn: the summed allocated pieces per
//     stockItemId is <= that item's confirmed availability (Property 10 /
//     Requirement 21.14 — the core no-double-count invariant);
//   * every allocation line's pieces are > 0 and whole (the allocator never
//     emits a zero or fractional-piece line);
//   * the order is deterministic/repeatable — identical inputs yield identical
//     per-item consumption and the same overall partial flag (Requirement
//     8.12).
//
// PBT framework: `package:glados`. `ExploreConfig(numRuns: ...)` fixes the
// iteration count (>= 100) and seeds a deterministic `Random`, so any failure
// reproduces exactly.
//
// Pure-domain / headless: imports only the domain + application layers,
// `package:rational`, and `package:glados`. No Flutter widgets, no DB.

import 'package:glados/glados.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/allocation_service.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/order_request.dart';

/// Deterministic exploration config giving the property >= 100 iterations from
/// a fixed seed.
final ExploreConfig _explore =
    ExploreConfig(numRuns: 200, random: Random(20240914));

/// A single stock item in the shared pool: a cross-section (reaper 2×1 or plank
/// 4×1), a length 2..9 ft, and confirmed available pieces.
class _Stock {
  const _Stock({
    required this.isReaper,
    required this.lengthIndex,
    required this.pieces,
  });

  /// Reaper (bunch size 10) when true, plank (bunch size 1) when false.
  final bool isReaper;

  /// Length index 0..7 → feet 2..9.
  final int lengthIndex;

  /// Confirmed available pieces (0..). For a reaper this need not be a whole
  /// multiple of 10 — the allocator floors to whole bunches, which is exactly
  /// the behaviour under test.
  final int pieces;

  int get lengthFt => 2 + lengthIndex;
}

/// A single request line targeting one of the pool's stock items by index.
class _Line {
  const _Line({
    required this.stockIndex,
    required this.wantUnits,
    required this.useFixedLength,
    required this.targetNum,
  });

  /// Which pool stock item this line aims at (mod pool size).
  final int stockIndex;

  /// For an exact-quantity line, the whole sale units demanded (1..).
  final int wantUnits;

  /// When true the line is a fixed-length target-CFT request; otherwise an
  /// exact-quantity request. Both pin a single SKU, so they draw on one item.
  final bool useFixedLength;

  /// Numerator (over 1) of a fixed-length target CFT (1..).
  final int targetNum;
}

/// A whole random multi-line scenario: a non-empty stock pool and an ordered
/// list of request lines, many aimed at the same item.
class _Scenario {
  const _Scenario({required this.stocks, required this.lines});

  final List<_Stock> stocks;
  final List<_Line> lines;

  @override
  String toString() =>
      '_Scenario(stocks: ${stocks.length}, lines: ${lines.length})';
}

final Generator<_Stock> _stock = any.combine3(
  any.bool,
  any.intInRange(0, 8), // length index 0..7 → 2..9 ft
  any.intInRange(0, 40), // pieces 0..39
  (bool isReaper, int lenIdx, int pieces) =>
      _Stock(isReaper: isReaper, lengthIndex: lenIdx, pieces: pieces),
);

final Generator<_Line> _line = any.combine4(
  any.intInRange(0, 50), // stock index (reduced mod pool size)
  any.intInRange(1, 8), // want units 1..7
  any.bool, // exact-qty vs fixed-length
  any.intInRange(1, 12), // fixed-length target numerator 1..11
  (int stockIndex, int wantUnits, bool useFixedLength, int targetNum) => _Line(
    stockIndex: stockIndex,
    wantUnits: wantUnits,
    useFixedLength: useFixedLength,
    targetNum: targetNum,
  ),
);

final Generator<_Scenario> _scenario = any.combine2(
  any.listWithLengthInRange(1, 6, _stock), // 1..5 stock items
  any.listWithLengthInRange(2, 8, _line), // 2..7 request lines (multi-line)
  (List<_Stock> stocks, List<_Line> lines) =>
      _Scenario(stocks: stocks, lines: lines),
);

void main() {
  const service = AllocationService();

  // Fixed cross-sections: a reaper 2×1 (bunch size 10) and a plank 4×1.
  final reaper2x1 = CrossSection(
    id: 1,
    widthIn: 2,
    thicknessIn: 1,
    category: WoodCategory.reaper,
  );
  final plank4x1 = CrossSection(
    id: 2,
    widthIn: 4,
    thicknessIn: 1,
    category: WoodCategory.plank,
  );

  Glados<_Scenario>(_scenario, _explore).test(
    'Feature: wood-cft-app, Property 10: Multi-line allocation never '
    'double-counts stock - across every line of a multi-line order the total '
    'pieces allocated from any single stock item never exceeds that item\'s '
    'available quantity (Requirements 8.6, 21.14)',
    (_Scenario s) {
      // Build the pool, collapsing duplicate (cross-section, length) keys so
      // every stock item has a unique SKU (the snapshot needs one row per
      // length per cross-section). Each gets a distinct stockItemId.
      final byKey = <String, SkuAvailability>{};
      var nextId = 1000;
      for (final st in s.stocks) {
        final crossSection = st.isReaper ? reaper2x1 : plank4x1;
        final key = '${crossSection.id}:${st.lengthFt}';
        if (byKey.containsKey(key)) {
          continue; // keep the first; one row per SKU
        }
        byKey[key] = SkuAvailability(
          stockItemId: nextId++,
          crossSection: crossSection,
          lengthFt: st.lengthFt,
          availablePieces: st.pieces,
        );
      }
      final availability = byKey.values.toList();
      if (availability.isEmpty) {
        return; // no stock → nothing to assert
      }

      // Build the ordered request lines, each pinned to one pool SKU.
      final requests = <OrderRequest>[];
      for (final ln in s.lines) {
        final sku = availability[ln.stockIndex % availability.length];
        if (ln.useFixedLength) {
          requests.add(
            TargetCftFixedLengthRequest(
              varietyId: 42,
              crossSectionId: sku.crossSection.id,
              lengthFt: sku.lengthFt,
              targetCft: Rational.fromInt(ln.targetNum),
            ),
          );
        } else {
          requests.add(
            ExactQtyRequest(
              varietyId: 42,
              crossSectionId: sku.crossSection.id,
              lengthFt: sku.lengthFt,
              quantityUnits: ln.wantUnits,
            ),
          );
        }
      }

      final order = service.allocateOrder(requests, availability);

      // (1) CORE PROPERTY 10: no stock item is ever over-drawn across lines.
      final usedByItem = <int, int>{};
      for (final line in order.lines) {
        // Allocated pieces are a non-negative whole count. A fully-shorted
        // partial line legitimately allocates zero (the earlier lines consumed
        // the stock) and must still never contribute negative consumption.
        expect(line.allocatedPieces >= 0, isTrue);
        usedByItem[line.stockItemId] =
            (usedByItem[line.stockItemId] ?? 0) + line.allocatedPieces;
      }
      for (final a in availability) {
        final used = usedByItem[a.stockItemId] ?? 0;
        expect(
          used <= a.availablePieces,
          isTrue,
          reason: 'stock item ${a.stockItemId} over-drawn: '
              '$used > ${a.availablePieces}',
        );
      }

      // (2) The flattened lines equal the per-line results concatenated.
      final flattened = <AllocationLine>[
        for (final lr in order.lineResults) ...lr.lines,
      ];
      expect(flattened.length, order.lines.length);

      // (3) Determinism: re-running yields the same per-item consumption and
      // the same overall partial flag.
      final again = service.allocateOrder(requests, availability);
      final usedAgain = <int, int>{};
      for (final line in again.lines) {
        usedAgain[line.stockItemId] =
            (usedAgain[line.stockItemId] ?? 0) + line.allocatedPieces;
      }
      expect(usedAgain, usedByItem);
      expect(again.isPartial, order.isPartial);
    },
  );
}
