/// Unit tests for the flexible-length reaper length-share heuristic (task 9.2).
///
/// Pure-domain / headless tests (no device, no DB) covering
/// `AllocationService.allocateFlexibleReaper` against design.md -> "Flexible
/// reaper length-share heuristic" and Requirements 8.7, 8.8, 8.9, 8.10, 8.12.
///
/// These pin the Requirement 21.11 group scenarios: abundance (shares roughly
/// 60/30/10 of allocated CFT, whole bunches), a preferred-group (6-7 ft)
/// shortage that redistributes to the other groups, no-2 ft stock that
/// redistributes, a total shortage labelled partial, 8-9 ft excluded unless the
/// fallback is enabled, and repeatability (same inputs -> identical result).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';
import 'package:wood_cft/application/allocation_service.dart';
import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/order_request.dart';

void main() {
  const calc = CalculationService();
  const service = AllocationService();

  // The one reaper cross-section allocated across lengths (bunch size 10).
  // cftPerBunch(L) = 2·1·L/144 · 10 = 5L/36 CFT per bunch.
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

  // Builds a confirmed-availability snapshot for one reaper length. `bunches`
  // is the number of whole bunches (× 10 pieces) available at that length.
  SkuAvailability avail(int lengthFt, int bunches, {int stockItemId = 0}) =>
      SkuAvailability(
        stockItemId: stockItemId == 0 ? 100 + lengthFt : stockItemId,
        crossSection: reaper2x1,
        lengthFt: lengthFt,
        availablePieces: bunches * reaper2x1.bunchSize,
      );

  TargetCftFlexCrossSectionRequest request(int targetCft) =>
      TargetCftFlexCrossSectionRequest(
        varietyId: 7,
        crossSectionId: reaper2x1.id,
        targetCft: Rational.fromInt(targetCft),
      );

  // Every allocation line is a whole number of bunches (multiple of 10 pieces).
  void expectAllWholeBunches(FlexibleReaperAllocation result) {
    for (final line in result.lines) {
      expect(line.unit, AllocationUnit.bunch);
      expect(line.allocatedPieces % reaper2x1.bunchSize, 0,
          reason: 'line @ ${line.lengthFt} ft is not a whole number of '
              'bunches');
      expect(line.allocatedUnits * reaper2x1.bunchSize, line.allocatedPieces);
    }
  }

  // The lengths that actually received an allocation, as a set.
  Set<int> usedLengths(FlexibleReaperAllocation result) =>
      {for (final l in result.lines) l.lengthFt};

  // The allocated bunches at a given length (0 if the length was not used).
  int bunchesAt(FlexibleReaperAllocation result, int lengthFt) => result.lines
      .where((l) => l.lengthFt == lengthFt)
      .fold(0, (sum, l) => sum + l.allocatedUnits);

  group('Req 21.11 — abundance', () {
    test('shares are roughly 60/30/10 of allocated CFT, all whole bunches', () {
      // Ample stock everywhere; target 10 CFT. Groups target 6 / 3 / 1 CFT.
      final result = service.allocateFlexibleReaper(
        request(10),
        [
          avail(6, 100),
          avail(7, 100),
          avail(3, 100),
          avail(4, 100),
          avail(5, 100),
          avail(2, 100),
        ],
      );

      expect(result.isPartial, isFalse);
      expectAllWholeBunches(result);
      // Preferred lower length within each group is used first: 6, 3, 2 ft.
      expect(usedLengths(result), {6, 3, 2});
      // {6,7}: ceil(6 ÷ 5/6) = 8 bunches (40/6 CFT); {3,4,5}: ceil(3 ÷ 5/12)
      // = 8 bunches (40/12); {2}: ceil(1 ÷ 5/18) = 4 bunches (20/18).
      expect(bunchesAt(result, 6), 8);
      expect(bunchesAt(result, 3), 8);
      expect(bunchesAt(result, 2), 4);
      // No excluded lengths used.
      expect(usedLengths(result).intersection({8, 9}), isEmpty);

      // Meet-or-exceed the overall target; billing uses actual allocated CFT.
      expect(result.allocatedCft.value >= request(10).targetCft, isTrue);
      final expectedTotal = calc.lineCftFor(reaper2x1, 6, 80).value +
          calc.lineCftFor(reaper2x1, 3, 80).value +
          calc.lineCftFor(reaper2x1, 2, 40).value;
      expect(result.allocatedCft.value, expectedTotal);

      // Shares roughly 60/30/10 of ALLOCATED CFT (approximate, stock-aware).
      final total = result.allocatedCft.value;
      final share6 = (calc.lineCftFor(reaper2x1, 6, 80).value / total)
          .toDouble();
      final share3 = (calc.lineCftFor(reaper2x1, 3, 80).value / total)
          .toDouble();
      final share2 = (calc.lineCftFor(reaper2x1, 2, 40).value / total)
          .toDouble();
      expect(share6, closeTo(0.60, 0.08));
      expect(share3, closeTo(0.30, 0.08));
      expect(share2, closeTo(0.10, 0.08));
    });
  });

  group('Req 21.11 — preferred-group (6-7 ft) shortage redistributes', () {
    test('deficit from the 60% group is carried to the other groups', () {
      // {6,7} capped at 2 bunches (6 ft only); {3,4,5} and {2} abundant.
      final result = service.allocateFlexibleReaper(
        request(10),
        [
          avail(6, 2),
          avail(3, 100),
          avail(4, 100),
          avail(5, 100),
          avail(2, 100),
        ],
      );

      expect(result.isPartial, isFalse);
      expectAllWholeBunches(result);
      // The preferred group gives everything it has (2 bunches @ 6 ft).
      expect(bunchesAt(result, 6), 2);
      // Its deficit (~4.33 CFT) is redistributed onto {3,4,5}: that group now
      // carries 3 + 4.333 ≈ 7.333 CFT → ceil(7.333 ÷ 5/12) = 18 bunches @ 3 ft.
      expect(bunchesAt(result, 3), 18);
      // {2} still gets its 10% share.
      expect(bunchesAt(result, 2), 4);
      // 8-9 ft never used; overall target met or exceeded.
      expect(usedLengths(result).intersection({8, 9}), isEmpty);
      expect(result.allocatedCft.value >= request(10).targetCft, isTrue);
    });
  });

  group('Req 21.11 — no 2 ft stock redistributes', () {
    test('absent 2 ft group is absorbed by the preferred groups', () {
      // No 2 ft stock at all; {6,7} and {3,4,5} abundant.
      final result = service.allocateFlexibleReaper(
        request(10),
        [
          avail(6, 100),
          avail(7, 100),
          avail(3, 100),
          avail(4, 100),
          avail(5, 100),
        ],
      );

      expect(result.isPartial, isFalse);
      expectAllWholeBunches(result);
      // 2 ft never appears because there is no stock there.
      expect(usedLengths(result).contains(2), isFalse);
      // The target is still met or exceeded from the available groups.
      expect(result.allocatedCft.value >= request(10).targetCft, isTrue);
      expect(usedLengths(result).intersection({8, 9}), isEmpty);
    });
  });

  group('Req 21.11 — total shortage is labelled partial', () {
    test('insufficient stock yields a partial with the exact CFT shortage', () {
      // Only 1 bunch @ 6 ft (5/6 CFT) against a 100 CFT target.
      final result = service.allocateFlexibleReaper(
        request(100),
        [avail(6, 1)],
      );

      expect(result.isPartial, isTrue);
      expect(result.isFullyAllocated, isFalse);
      expectAllWholeBunches(result);
      expect(bunchesAt(result, 6), 1);
      expect(result.allocatedCft, calc.lineCftFor(reaper2x1, 6, 10));
      // Shortage = target − allocated, exact.
      expect(
        result.shortageCft.value,
        request(100).targetCft - result.allocatedCft.value,
      );
      // Never claimed fulfilled.
      expect(result.allocatedCft.value < request(100).targetCft, isTrue);
    });

    test('no eligible stock yields an empty partial with the full shortage',
        () {
      final result = service.allocateFlexibleReaper(
        request(5),
        const [],
      );
      expect(result.isPartial, isTrue);
      expect(result.lines, isEmpty);
      expect(result.allocatedCft, calc.totalCft(const []));
      expect(result.shortageCft.value, request(5).targetCft);
    });
  });

  group('Req 21.11 — 8-9 ft excluded unless fallback enabled', () {
    test('with only 8-9 ft stock and fallback off, nothing is allocated', () {
      final result = service.allocateFlexibleReaper(
        request(5),
        [avail(8, 100), avail(9, 100)],
      );
      // 8/9 ft are excluded by default (Requirement 8.9) → nothing eligible.
      expect(result.lines, isEmpty);
      expect(result.isPartial, isTrue);
      expect(result.shortageCft.value, request(5).targetCft);
    });

    test('with fallback enabled, 8 ft (lower length) is used', () {
      final result = service.allocateFlexibleReaper(
        request(5),
        [avail(8, 100), avail(9, 100)],
        allow89ftFallback: true,
      );
      expect(result.isPartial, isFalse);
      expectAllWholeBunches(result);
      // Lower length first within the preferred group: 8 ft before 9 ft.
      expect(usedLengths(result).contains(8), isTrue);
      expect(result.allocatedCft.value >= request(5).targetCft, isTrue);
    });

    test('8-9 ft never used when preferred stock exists and fallback off', () {
      final result = service.allocateFlexibleReaper(
        request(10),
        [
          avail(6, 100),
          avail(7, 100),
          avail(8, 100),
          avail(9, 100),
          avail(3, 100),
          avail(2, 100),
        ],
      );
      expect(result.isPartial, isFalse);
      expect(usedLengths(result).intersection({8, 9}), isEmpty);
    });
  });

  group('Req 21.11 — repeatability (deterministic)', () {
    test('identical inputs produce an identical result (run twice)', () {
      List<SkuAvailability> stock() => [
            avail(6, 2),
            avail(7, 3),
            avail(3, 5),
            avail(4, 4),
            avail(5, 2),
            avail(2, 7),
          ];

      final first = service.allocateFlexibleReaper(request(8), stock());
      final second = service.allocateFlexibleReaper(request(8), stock());

      expect(first.lines.length, second.lines.length);
      for (var i = 0; i < first.lines.length; i++) {
        final a = first.lines[i];
        final b = second.lines[i];
        expect(a.lengthFt, b.lengthFt);
        expect(a.stockItemId, b.stockItemId);
        expect(a.allocatedUnits, b.allocatedUnits);
        expect(a.allocatedCft, b.allocatedCft);
      }
      expect(first.allocatedCft, second.allocatedCft);
      expect(first.isPartial, second.isPartial);
      expect(first.shortageCft, second.shortageCft);
    });
  });

  group('guards', () {
    test('rejects a non-reaper cross-section (no reaper shares on planks)', () {
      expect(
        () => service.allocateFlexibleReaper(
          TargetCftFlexCrossSectionRequest(
            varietyId: 7,
            crossSectionId: plank4x1.id,
            targetCft: Rational.fromInt(5),
          ),
          [
            SkuAvailability(
              stockItemId: 200,
              crossSection: plank4x1,
              lengthFt: 6,
              availablePieces: 100,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects availability whose cross-section is not the request one', () {
      final otherReaper = CrossSection(
        id: 9,
        widthIn: 3,
        thicknessIn: 1,
        category: WoodCategory.reaper,
      );
      expect(
        () => service.allocateFlexibleReaper(
          request(5),
          [
            SkuAvailability(
              stockItemId: 1,
              crossSection: otherReaper, // id 9 ≠ request cross-section 1
              lengthFt: 6,
              availablePieces: 100,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}
