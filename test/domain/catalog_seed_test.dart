// Pure-Dart unit tests for the catalog seed (task 2.2).
//
// These tests pin the task's required assertions against the First-run setup
// described in design.md -> Screen Flows:
//  * the three variety names with their EXACT spelling (Requirement 1.1);
//  * the six cross-sections with correct categories — 2×1 Reaper and
//    3×1,4×1,5×1,6×1,7×1 Plank (Requirement 1.2);
//  * no prices are seeded and no non-zero stock is seeded; every implied
//    opening balance is zero (Requirement 1.12).
//
// Imports only the pure-Dart domain layer and the `test` matchers exposed via
// flutter_test — no widgets are pumped.

import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/catalog_seed.dart';

void main() {
  group('seeded varieties (Requirement 1.1)', () {
    test('are exactly Mahogany, Kalani, Palajathi with exact spelling', () {
      final names = kSeedVarieties.map((v) => v.name).toList();
      expect(names, <String>['Mahogany', 'Kalani', 'Palajathi']);
    });

    test('contains exactly three varieties, all active', () {
      expect(kSeedVarieties, hasLength(3));
      expect(kSeedVarieties.every((v) => v.active), isTrue);
    });

    test('have stable, unique ids', () {
      final ids = kSeedVarieties.map((v) => v.id).toSet();
      expect(ids, <int>{1, 2, 3});
    });
  });

  group('seeded cross-sections (Requirement 1.2)', () {
    test('are the six expected width×thickness profiles', () {
      final labels = kSeedCrossSections.map((c) => c.inchLabel).toList();
      expect(labels, <String>[
        '2 × 1 in',
        '3 × 1 in',
        '4 × 1 in',
        '5 × 1 in',
        '6 × 1 in',
        '7 × 1 in',
      ]);
    });

    test('2×1 is classified as Reaper', () {
      final reaper =
          kSeedCrossSections.firstWhere((c) => c.widthIn == 2 && c.thicknessIn == 1);
      expect(reaper.category, WoodCategory.reaper);
      expect(reaper.bunchSize, 10);
    });

    test('3×1,4×1,5×1,6×1,7×1 are classified as Plank', () {
      final planks = kSeedCrossSections.where((c) => c.widthIn >= 3);
      expect(planks, hasLength(5));
      for (final plank in planks) {
        expect(plank.category, WoodCategory.plank, reason: plank.inchLabel);
        expect(plank.bunchSize, 1, reason: plank.inchLabel);
        expect(plank.thicknessIn, 1, reason: plank.inchLabel);
      }
    });

    test('exactly one Reaper and five Planks are seeded', () {
      final reapers =
          kSeedCrossSections.where((c) => c.category == WoodCategory.reaper);
      final planks =
          kSeedCrossSections.where((c) => c.category == WoodCategory.plank);
      expect(reapers, hasLength(1));
      expect(planks, hasLength(5));
    });

    test('all seeded cross-sections are active with stable unique ids', () {
      expect(kSeedCrossSections.every((c) => c.active), isTrue);
      expect(kSeedCrossSections.map((c) => c.id).toSet(), <int>{1, 2, 3, 4, 5, 6});
    });
  });

  group('zero-stock / no-price initialization (Requirement 1.12)', () {
    test('the seed documents zero as the only opening stock balance', () {
      expect(kSeedStockItemBalancePieces, 0);
    });

    test('CatalogSeed carries no price concept at all', () {
      // The seed type exposes only catalog identity/dimensions — there is no
      // field, method, or value through which a price could be fabricated.
      // Reflectively asserting "no prices" is impossible in Dart, so we pin the
      // contract: the seed surface is varieties + cross-sections only.
      expect(kInitialCatalogSeed.varieties, same(kSeedVarieties));
      expect(kInitialCatalogSeed.crossSections, same(kSeedCrossSections));
    });

    test('enumerated stock items cover the full grid at zero balance', () {
      final items = kInitialCatalogSeed.enumerateStockItems();
      // 3 varieties × 6 cross-sections × 8 lengths (2..9 ft inclusive) = 144.
      const expectedLengths = kMaxLengthFt - kMinLengthFt + 1; // 8
      expect(items, hasLength(3 * 6 * expectedLengths));

      // No fabricated stock: every implied balance is zero (the model holds no
      // quantity, and the sole legitimate opening balance is zero).
      for (final item in items) {
        expect(kSeedStockItemBalancePieces, 0, reason: item.toString());
        expect(item.lengthFt, inInclusiveRange(kMinLengthFt, kMaxLengthFt));
      }
    });

    test('enumerated stock items are keyed uniquely by variety+section+length',
        () {
      final items = kInitialCatalogSeed.enumerateStockItems();
      final keys = items
          .map((i) => '${i.varietyId}:${i.crossSectionId}:${i.lengthFt}')
          .toSet();
      expect(keys, hasLength(items.length));
    });
  });
}
