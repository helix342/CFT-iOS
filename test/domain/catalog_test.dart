// Pure-Dart unit tests for the catalog domain models (task 2.1):
// WoodVariety, CrossSection, StockItem.
//
// These tests pin the task's required assertions:
//  * the inch label format "W × T in" (e.g. "2 × 1 in") — Requirement 1.8;
//  * that the SECOND dimension is the thickness used in the volume formula
//    (Requirement 1.9);
//  * Reaper bunch_size 10 / Plank bunch_size 1 (Requirements 3.1, 3.3);
//  * Length_Ft validation rejects < 2 and > 9 and accepts 2–9 inclusive
//    (Requirement 1.10), keeping inches (width/thickness) and feet (length)
//    distinct (Requirement 1.11).
//
// Imports only the pure-Dart domain layer and the `test` matchers exposed via
// flutter_test — no widgets are pumped.

import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/domain/catalog.dart';

void main() {
  group('WoodVariety', () {
    test('preserves the exact spelling given and defaults to active', () {
      const variety = WoodVariety(id: 1, name: 'Palajathi');
      expect(variety.name, 'Palajathi');
      expect(variety.active, isTrue);
    });

    test('can be deactivated without losing identity or name', () {
      const variety = WoodVariety(id: 2, name: 'Kalani');
      final deactivated = variety.copyWith(active: false);
      expect(deactivated.active, isFalse);
      expect(deactivated.id, 2);
      expect(deactivated.name, 'Kalani');
    });

    test('value equality compares id, name, and active', () {
      const a = WoodVariety(id: 1, name: 'Mahogany');
      const b = WoodVariety(id: 1, name: 'Mahogany');
      const c = WoodVariety(id: 1, name: 'mahogany');
      expect(a, equals(b));
      expect(a == c, isFalse);
    });
  });

  group('CrossSection inch label (Req 1.8)', () {
    test('formats a 2x1 reaper as "2 × 1 in"', () {
      final cs = CrossSection(
        id: 1,
        widthIn: 2,
        thicknessIn: 1,
        category: WoodCategory.reaper,
      );
      expect(cs.inchLabel, '2 × 1 in');
    });

    test('formats a 7x1 plank as "7 × 1 in"', () {
      final cs = CrossSection(
        id: 2,
        widthIn: 7,
        thicknessIn: 1,
        category: WoodCategory.plank,
      );
      expect(cs.inchLabel, '7 × 1 in');
    });
  });

  group('CrossSection dimension order (Req 1.9)', () {
    test('the second dimension is stored as the thickness', () {
      // A deliberately asymmetric profile proves width is first, thickness
      // second — the thickness is the dimension used in W × T × L / 144.
      final cs = CrossSection(
        id: 3,
        widthIn: 5,
        thicknessIn: 2,
        category: WoodCategory.plank,
      );
      expect(cs.widthIn, 5);
      expect(cs.thicknessIn, 2);
      expect(cs.inchLabel, '5 × 2 in');

      // The second value in the label is the thickness, not the width.
      final secondDimension = cs.inchLabel.split('×')[1].trim();
      expect(secondDimension, '2 in');
      expect(secondDimension.startsWith('${cs.thicknessIn}'), isTrue);
    });

    test('rejects non-positive inch dimensions', () {
      expect(
        () => CrossSection(
          id: 4,
          widthIn: 0,
          thicknessIn: 1,
          category: WoodCategory.plank,
        ),
        throwsArgumentError,
      );
      expect(
        () => CrossSection(
          id: 5,
          widthIn: 2,
          thicknessIn: 0,
          category: WoodCategory.reaper,
        ),
        throwsArgumentError,
      );
    });
  });

  group('CrossSection bunch size (Req 3.1, 3.3)', () {
    test('a reaper has a bunch size of 10', () {
      final reaper = CrossSection(
        id: 6,
        widthIn: 2,
        thicknessIn: 1,
        category: WoodCategory.reaper,
      );
      expect(reaper.bunchSize, 10);
      expect(WoodCategory.reaper.bunchSize, 10);
    });

    test('a plank has a bunch size of 1', () {
      final plank = CrossSection(
        id: 7,
        widthIn: 3,
        thicknessIn: 1,
        category: WoodCategory.plank,
      );
      expect(plank.bunchSize, 1);
      expect(WoodCategory.plank.bunchSize, 1);
    });

    test('rejects a bunch size that disagrees with the category', () {
      expect(
        () => CrossSection(
          id: 8,
          widthIn: 2,
          thicknessIn: 1,
          category: WoodCategory.reaper,
          bunchSize: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => CrossSection(
          id: 9,
          widthIn: 3,
          thicknessIn: 1,
          category: WoodCategory.plank,
          bunchSize: 10,
        ),
        throwsArgumentError,
      );
    });

    test('copyWith to a new category recomputes the bunch size', () {
      final reaper = CrossSection(
        id: 10,
        widthIn: 2,
        thicknessIn: 1,
        category: WoodCategory.reaper,
      );
      final asPlank = reaper.copyWith(category: WoodCategory.plank);
      expect(asPlank.category, WoodCategory.plank);
      expect(asPlank.bunchSize, 1);
    });
  });

  group('StockItem length validation (Req 1.10)', () {
    test('accepts every length in the inclusive 2–9 ft range', () {
      for (var length = kMinLengthFt; length <= kMaxLengthFt; length++) {
        final item = StockItem(
          id: length,
          varietyId: 1,
          crossSectionId: 1,
          lengthFt: length,
        );
        expect(item.lengthFt, length);
      }
    });

    test('rejects a length below 2 ft', () {
      expect(
        () => StockItem(
          id: 1,
          varietyId: 1,
          crossSectionId: 1,
          lengthFt: 1,
        ),
        throwsRangeError,
      );
    });

    test('rejects a length above 9 ft', () {
      expect(
        () => StockItem(
          id: 1,
          varietyId: 1,
          crossSectionId: 1,
          lengthFt: 10,
        ),
        throwsRangeError,
      );
    });

    test('copyWith re-validates the length against the 2–9 ft range', () {
      final item = StockItem(
        id: 1,
        varietyId: 1,
        crossSectionId: 1,
        lengthFt: 6,
      );
      expect(() => item.copyWith(lengthFt: 0), throwsRangeError);
      expect(item.copyWith(lengthFt: 9).lengthFt, 9);
    });

    test('is keyed by variety + cross-section + length', () {
      final a = StockItem(
        id: 1,
        varietyId: 1,
        crossSectionId: 2,
        lengthFt: 6,
      );
      final b = StockItem(
        id: 1,
        varietyId: 1,
        crossSectionId: 2,
        lengthFt: 6,
      );
      final different = StockItem(
        id: 1,
        varietyId: 1,
        crossSectionId: 2,
        lengthFt: 7,
      );
      expect(a, equals(b));
      expect(a == different, isFalse);
    });
  });
}
