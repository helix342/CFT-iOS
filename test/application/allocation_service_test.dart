/// Unit tests for the exact-quantity allocator (task 8.1).
///
/// These are pure-domain / headless tests (no device, no DB) covering the
/// exact-quantity path of design.md -> Allocation Behavior and Requirements
/// 7.1, 7.2, 8.1, 8.3:
///
///   * the four structured request value objects construct and validate
///     (Requirement 7.1 — structured only);
///   * an exact-quantity request within confirmed stock allocates exactly and
///     computes the correct CFT (Requirements 7.2, 8.1);
///   * an over-stock request yields a clearly-labelled PARTIAL with the exact
///     shortage, never silently reduced (Requirement 8.3);
///   * reaper quantities respect the whole-bunch (multiple-of-10) unit rule
///     (Requirement 8.1).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';
import 'package:wood_cft/application/allocation_service.dart';
import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/cft.dart';
import 'package:wood_cft/domain/order_request.dart';

void main() {
  const calc = CalculationService();
  const service = AllocationService();

  // A reaper 2×1 cross-section (bunch size 10) and a plank 4×1 (piece unit).
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

  group('OrderRequest value objects — structured construction + validation', () {
    test('all four request kinds construct with the right discriminator', () {
      final exact = ExactQtyRequest(
        varietyId: 7,
        crossSectionId: reaper2x1.id,
        lengthFt: 6,
        quantityUnits: 3,
      );
      final fixedLen = TargetCftFixedLengthRequest(
        varietyId: 7,
        crossSectionId: reaper2x1.id,
        lengthFt: 6,
        targetCft: Rational.fromInt(5),
      );
      final flexXs = TargetCftFlexCrossSectionRequest(
        varietyId: 7,
        crossSectionId: reaper2x1.id,
        targetCft: Rational.fromInt(5),
      );
      final flexCat = TargetCftFlexCategoryRequest(
        varietyId: 7,
        category: WoodCategory.plank,
        targetCft: Rational.fromInt(5),
      );

      expect(exact.kind, OrderRequestKind.exactQty);
      expect(fixedLen.kind, OrderRequestKind.targetCftFixedLength);
      expect(flexXs.kind, OrderRequestKind.targetCftFlexCrossSection);
      expect(flexCat.kind, OrderRequestKind.targetCftFlexCategory);

      // Carried constraints are preserved.
      expect(exact.quantityUnits, 3);
      expect(fixedLen.lengthFt, 6);
      expect(flexXs.crossSectionId, reaper2x1.id);
      expect(flexCat.category, WoodCategory.plank);
    });

    test('exact-quantity rejects non-positive quantity', () {
      expect(
        () => ExactQtyRequest(
          varietyId: 1,
          crossSectionId: 1,
          lengthFt: 6,
          quantityUnits: 0,
        ),
        throwsArgumentError,
      );
    });

    test('fixed-length requests reject out-of-range length', () {
      expect(
        () => TargetCftFixedLengthRequest(
          varietyId: 1,
          crossSectionId: 1,
          lengthFt: 10,
          targetCft: Rational.fromInt(5),
        ),
        throwsRangeError,
      );
      expect(
        () => ExactQtyRequest(
          varietyId: 1,
          crossSectionId: 1,
          lengthFt: 1,
          quantityUnits: 2,
        ),
        throwsRangeError,
      );
    });

    test('target-CFT shapes reject a non-positive target', () {
      expect(
        () => TargetCftFlexCrossSectionRequest(
          varietyId: 1,
          crossSectionId: 1,
          targetCft: Rational.zero,
        ),
        throwsArgumentError,
      );
      expect(
        () => TargetCftFlexCategoryRequest(
          varietyId: 1,
          category: WoodCategory.reaper,
          targetCft: Rational.fromInt(-1),
        ),
        throwsArgumentError,
      );
    });

    test('value equality holds for identical requests', () {
      final a = ExactQtyRequest(
        varietyId: 7,
        crossSectionId: 1,
        lengthFt: 6,
        quantityUnits: 3,
      );
      final b = ExactQtyRequest(
        varietyId: 7,
        crossSectionId: 1,
        lengthFt: 6,
        quantityUnits: 3,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('allocateExact — reaper (whole-bunch units)', () {
    test('request within stock allocates exactly with correct CFT', () {
      // 3 bunches of Mahogany 2×1 @ 6 ft → 30 pieces, 2.5 CFT (Req 21.5).
      final request = ExactQtyRequest(
        varietyId: 7,
        crossSectionId: reaper2x1.id,
        lengthFt: 6,
        quantityUnits: 3,
      );
      final availability = SkuAvailability(
        stockItemId: 100,
        crossSection: reaper2x1,
        lengthFt: 6,
        availablePieces: 50, // 5 bunches available
      );

      final line = service.allocateExact(request, availability);

      expect(line.isFullyAllocated, isTrue);
      expect(line.isPartial, isFalse);
      expect(line.unit, AllocationUnit.bunch);
      expect(line.allocatedUnits, 3);
      expect(line.allocatedPieces, 30);
      expect(line.shortageUnits, 0);
      expect(line.shortagePieces, 0);
      // Exact CFT equals the shared engine's line value: 30 × (2·1·6/144) = 2.5.
      expect(line.allocatedCft, calc.lineCftFor(reaper2x1, 6, 30));
      expect(line.allocatedCft.toFixed(), '2.5000');
    });

    test('allocated piece count is always a multiple of the bunch size', () {
      final request = ExactQtyRequest(
        varietyId: 7,
        crossSectionId: reaper2x1.id,
        lengthFt: 6,
        quantityUnits: 4,
      );
      final availability = SkuAvailability(
        stockItemId: 100,
        crossSection: reaper2x1,
        lengthFt: 6,
        availablePieces: 100,
      );

      final line = service.allocateExact(request, availability);
      expect(line.allocatedPieces % reaper2x1.bunchSize, 0);
      expect(line.allocatedPieces, 40);
    });

    test('over-stock request yields a labelled partial with the exact shortage',
        () {
      // Demand 5 bunches (50 pcs) but only 32 pcs confirmed → 3 whole bunches
      // fit (30 pcs); 2 bunches (20 pcs) short. Never silently reduced.
      final request = ExactQtyRequest(
        varietyId: 7,
        crossSectionId: reaper2x1.id,
        lengthFt: 6,
        quantityUnits: 5,
      );
      final availability = SkuAvailability(
        stockItemId: 100,
        crossSection: reaper2x1,
        lengthFt: 6,
        availablePieces: 32,
      );

      final line = service.allocateExact(request, availability);

      expect(line.isPartial, isTrue);
      expect(line.isFullyAllocated, isFalse);
      // Only whole bunches that fit are allocated (floor 32/10 = 3).
      expect(line.allocatedUnits, 3);
      expect(line.allocatedPieces, 30);
      // Shortage is demand − allocated, in both units and pieces.
      expect(line.shortageUnits, 2);
      expect(line.shortagePieces, 20);
      // The original demand is preserved on the request (not mutated).
      expect(request.quantityUnits, 5);
      // CFT is for the ALLOCATED pieces only, computed by the shared engine.
      expect(line.allocatedCft, calc.lineCftFor(reaper2x1, 6, 30));
    });

    test('zero available stock yields a partial with zero allocated', () {
      final request = ExactQtyRequest(
        varietyId: 7,
        crossSectionId: reaper2x1.id,
        lengthFt: 6,
        quantityUnits: 2,
      );
      final availability = SkuAvailability(
        stockItemId: 100,
        crossSection: reaper2x1,
        lengthFt: 6,
        availablePieces: 0,
      );

      final line = service.allocateExact(request, availability);

      expect(line.isPartial, isTrue);
      expect(line.allocatedUnits, 0);
      expect(line.allocatedPieces, 0);
      expect(line.allocatedCft, Cft.zero);
      expect(line.shortageUnits, 2);
      expect(line.shortagePieces, 20);
    });

    test('partial pending stock below one bunch allocates nothing', () {
      // 9 confirmed pieces is less than one bunch → 0 whole bunches fit.
      final request = ExactQtyRequest(
        varietyId: 7,
        crossSectionId: reaper2x1.id,
        lengthFt: 6,
        quantityUnits: 1,
      );
      final availability = SkuAvailability(
        stockItemId: 100,
        crossSection: reaper2x1,
        lengthFt: 6,
        availablePieces: 9,
      );

      final line = service.allocateExact(request, availability);
      expect(line.isPartial, isTrue);
      expect(line.allocatedUnits, 0);
      expect(line.allocatedPieces, 0);
      expect(line.shortageUnits, 1);
      expect(line.shortagePieces, 10);
    });
  });

  group('allocateExact — plank (piece units)', () {
    test('request within stock allocates exact pieces with correct CFT', () {
      // 5 pieces of 4×1 @ 6 ft. per-piece = 4·1·6/144 = 1/6 CFT.
      final request = ExactQtyRequest(
        varietyId: 7,
        crossSectionId: plank4x1.id,
        lengthFt: 6,
        quantityUnits: 5,
      );
      final availability = SkuAvailability(
        stockItemId: 200,
        crossSection: plank4x1,
        lengthFt: 6,
        availablePieces: 12,
      );

      final line = service.allocateExact(request, availability);

      expect(line.unit, AllocationUnit.piece);
      expect(line.isPartial, isFalse);
      expect(line.allocatedUnits, 5);
      expect(line.allocatedPieces, 5);
      expect(line.allocatedCft, calc.lineCftFor(plank4x1, 6, 5));
    });

    test('over-stock plank yields a labelled partial with piece shortage', () {
      final request = ExactQtyRequest(
        varietyId: 7,
        crossSectionId: plank4x1.id,
        lengthFt: 6,
        quantityUnits: 10,
      );
      final availability = SkuAvailability(
        stockItemId: 200,
        crossSection: plank4x1,
        lengthFt: 6,
        availablePieces: 4,
      );

      final line = service.allocateExact(request, availability);

      expect(line.isPartial, isTrue);
      expect(line.allocatedUnits, 4);
      expect(line.allocatedPieces, 4);
      expect(line.shortageUnits, 6);
      expect(line.shortagePieces, 6);
      expect(line.allocatedCft, calc.lineCftFor(plank4x1, 6, 4));
    });
  });

  group('allocateTargetCftFixedLength — single-SKU meet-or-exceed (task 9.1)',
      () {
    test('Req 21.9: 5 CFT of 2×1 @ 6 ft reaper → 6 bunches / 60 pieces', () {
      // per-piece = 2·1·6/144 = 1/12; bunch = 10/12 = 5/6 CFT. ceil(5 ÷ 5/6)
      // = ceil(6) = 6 bunches = 60 pieces (meet-or-exceed; exactly 5 CFT).
      final request = TargetCftFixedLengthRequest(
        varietyId: 7,
        crossSectionId: reaper2x1.id,
        lengthFt: 6,
        targetCft: Rational.fromInt(5),
      );
      final availability = SkuAvailability(
        stockItemId: 100,
        crossSection: reaper2x1,
        lengthFt: 6,
        availablePieces: 200, // ample
      );

      final line = service.allocateTargetCftFixedLength(request, availability);

      expect(line.isPartial, isFalse);
      expect(line.unit, AllocationUnit.bunch);
      expect(line.allocatedUnits, 6);
      expect(line.allocatedPieces, 60);
      // Billed on ACTUAL allocated CFT, never the target.
      expect(line.allocatedCft, calc.lineCftFor(reaper2x1, 6, 60));
      // 6 bunches of 5/6 CFT each = exactly 5 CFT (meets the target exactly).
      expect(line.allocatedCft.value, Rational.fromInt(5));
      // Allocated CFT ≥ target, and one fewer bunch would fall short:
      // 5 bunches = 50 pcs = 50/12 ≈ 4.1667 CFT < 5.
      expect(line.allocatedCft.value >= request.targetCft, isTrue);
      expect(calc.lineCftFor(reaper2x1, 6, 50).value < request.targetCft,
          isTrue);
    });

    test('Req 21.10: 5 CFT of 2×1 @ 7 ft reaper → 6 bunches (4.8611<5<5.8333)',
        () {
      // per-piece = 2·1·7/144 = 7/72; bunch = 70/72 = 35/36 CFT ≈ 0.9722.
      // 5 bunches = 175/36 ≈ 4.8611 (< 5); 6 bunches = 210/36 ≈ 5.8333 (≥ 5).
      // ceil(5 ÷ 35/36) = ceil(180/35) = ceil(5.142…) = 6 → meet-or-exceed.
      final request = TargetCftFixedLengthRequest(
        varietyId: 7,
        crossSectionId: reaper2x1.id,
        lengthFt: 7,
        targetCft: Rational.fromInt(5),
      );
      final availability = SkuAvailability(
        stockItemId: 101,
        crossSection: reaper2x1,
        lengthFt: 7,
        availablePieces: 200,
      );

      final line = service.allocateTargetCftFixedLength(request, availability);

      expect(line.isPartial, isFalse);
      expect(line.allocatedUnits, 6);
      expect(line.allocatedPieces, 60);
      // 5 bunches would be below target; 6 is the smallest that meets/exceeds.
      final fiveBunches = calc.lineCftFor(reaper2x1, 7, 50).value;
      final sixBunches = calc.lineCftFor(reaper2x1, 7, 60).value;
      expect(fiveBunches < request.targetCft, isTrue);
      expect(sixBunches >= request.targetCft, isTrue);
      expect(line.allocatedCft.value, sixBunches);
      // Display sanity: 4.8611 / 5.8333.
      expect(Cft(fiveBunches).toFixed(), '4.8611');
      expect(line.allocatedCft.toFixed(), '5.8333');
    });

    test('plank target-CFT ceil: 1.25 CFT of 4×1 @ 6 ft → 8 pieces', () {
      // per-piece = 4·1·6/144 = 1/6 CFT. ceil(5/4 ÷ 1/6) = ceil(7.5) = 8 pieces
      // = 8/6 ≈ 1.3333 CFT ≥ 1.25; 7 pieces = 7/6 ≈ 1.1667 < 1.25.
      final request = TargetCftFixedLengthRequest(
        varietyId: 7,
        crossSectionId: plank4x1.id,
        lengthFt: 6,
        targetCft: Rational(BigInt.from(5), BigInt.from(4)),
      );
      final availability = SkuAvailability(
        stockItemId: 200,
        crossSection: plank4x1,
        lengthFt: 6,
        availablePieces: 50,
      );

      final line = service.allocateTargetCftFixedLength(request, availability);

      expect(line.isPartial, isFalse);
      expect(line.unit, AllocationUnit.piece);
      expect(line.allocatedUnits, 8);
      expect(line.allocatedPieces, 8);
      expect(line.allocatedCft, calc.lineCftFor(plank4x1, 6, 8));
      expect(line.allocatedCft.value >= request.targetCft, isTrue);
      // 7 pieces would be the largest under-target option.
      expect(calc.lineCftFor(plank4x1, 6, 7).value < request.targetCft, isTrue);
    });

    test('understock: fixed length cannot reach target → labelled partial', () {
      // Needs 6 bunches (21.9) but only 42 confirmed pieces → 4 whole bunches
      // fit; 2 bunches short. Partial, never fulfilled, never mixing lengths.
      final request = TargetCftFixedLengthRequest(
        varietyId: 7,
        crossSectionId: reaper2x1.id,
        lengthFt: 6,
        targetCft: Rational.fromInt(5),
      );
      final availability = SkuAvailability(
        stockItemId: 100,
        crossSection: reaper2x1,
        lengthFt: 6,
        availablePieces: 42, // 4 whole bunches fit (40 pcs)
      );

      final line = service.allocateTargetCftFixedLength(request, availability);

      expect(line.isPartial, isTrue);
      expect(line.isFullyAllocated, isFalse);
      expect(line.allocatedUnits, 4);
      expect(line.allocatedPieces, 40);
      // Shortage is target-required (6) minus allocatable (4) whole units.
      expect(line.shortageUnits, 2);
      expect(line.shortagePieces, 20);
      // Allocated never exceeds confirmed stock; CFT is on allocated pieces.
      expect(line.allocatedPieces, lessThanOrEqualTo(42));
      expect(line.allocatedCft, calc.lineCftFor(reaper2x1, 6, 40));
      // Allocated CFT is below target — honestly a partial, not fulfilled.
      expect(line.allocatedCft.value < request.targetCft, isTrue);
    });

    test('zero confirmed stock → partial with zero allocated, full shortage',
        () {
      final request = TargetCftFixedLengthRequest(
        varietyId: 7,
        crossSectionId: reaper2x1.id,
        lengthFt: 6,
        targetCft: Rational.fromInt(5),
      );
      final availability = SkuAvailability(
        stockItemId: 100,
        crossSection: reaper2x1,
        lengthFt: 6,
        availablePieces: 0,
      );

      final line = service.allocateTargetCftFixedLength(request, availability);

      expect(line.isPartial, isTrue);
      expect(line.allocatedUnits, 0);
      expect(line.allocatedPieces, 0);
      expect(line.allocatedCft, Cft.zero);
      expect(line.shortageUnits, 6); // full required unit count
    });

    test('SKU mismatch (cross-section / length) is rejected', () {
      final request = TargetCftFixedLengthRequest(
        varietyId: 7,
        crossSectionId: reaper2x1.id,
        lengthFt: 6,
        targetCft: Rational.fromInt(5),
      );
      expect(
        () => service.allocateTargetCftFixedLength(
          request,
          SkuAvailability(
            stockItemId: 200,
            crossSection: plank4x1, // wrong cross-section
            lengthFt: 6,
            availablePieces: 10,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => service.allocateTargetCftFixedLength(
          request,
          SkuAvailability(
            stockItemId: 100,
            crossSection: reaper2x1,
            lengthFt: 7, // wrong length
            availablePieces: 10,
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('allocateFlexiblePlank — whole-piece min-excess (task 9.3)', () {
    // A plank 4×1: per-piece CFT at length L is 4·1·L/144 = L/36.
    SkuAvailability plankAt(int stockItemId, int lengthFt, int pieces) =>
        SkuAvailability(
          stockItemId: stockItemId,
          crossSection: plank4x1,
          lengthFt: lengthFt,
          availablePieces: pieces,
        );

    test('target met with whole pieces at the smallest excess (single length)',
        () {
      // Target 1.25 CFT of 4×1 @ 6 ft only. per-piece = 1/6 CFT.
      // 7 pieces = 7/6 ≈ 1.1667 (< 1.25); 8 pieces = 8/6 ≈ 1.3333 (≥ 1.25).
      final request = TargetCftFlexCrossSectionRequest(
        varietyId: 7,
        crossSectionId: plank4x1.id,
        targetCft: Rational(BigInt.from(5), BigInt.from(4)),
      );
      final result = service.allocateFlexiblePlank(
        request,
        [plankAt(200, 6, 50)],
      );

      expect(result.isPartial, isFalse);
      expect(result.lines, hasLength(1));
      final line = result.lines.single;
      expect(line.unit, AllocationUnit.piece);
      expect(line.lengthFt, 6);
      expect(line.allocatedPieces, 8);
      expect(line.allocatedUnits, 8);
      // Billed on actual allocated CFT, meets-or-exceeds, minimal excess.
      expect(result.allocatedCft, calc.lineCftFor(plank4x1, 6, 8));
      expect(result.allocatedCft.value >= request.targetCft, isTrue);
      // One fewer piece would fall short.
      expect(calc.lineCftFor(plank4x1, 6, 7).value < request.targetCft, isTrue);
    });

    test('reaches an exact zero-excess meet across lengths (min excess)', () {
      // per-piece = L/36. Target 7/36 CFT → thresholdUnits = 7 length-units.
      // A length-unit sum of exactly 7 is reachable (e.g. 2+2+3 or a single 7),
      // so the allocation meets the target EXACTLY with zero excess. The
      // documented tie-break prefers LOWER lengths first, so the reconstruction
      // favours the 2 ft/3 ft pieces over the single 7 ft piece — both are
      // equally minimal in excess (zero), the tie-break decides the mix.
      final request = TargetCftFlexCrossSectionRequest(
        varietyId: 7,
        crossSectionId: plank4x1.id,
        targetCft: Rational(BigInt.from(7), BigInt.from(36)),
      );
      final result = service.allocateFlexiblePlank(
        request,
        [
          plankAt(10, 2, 5),
          plankAt(11, 3, 5),
          plankAt(12, 7, 5),
        ],
      );

      expect(result.isPartial, isFalse);
      // Exact meet: allocated CFT equals the target (zero excess).
      expect(result.allocatedCft.value, request.targetCft);
      // Total length-units allocated is exactly the threshold (7) — minimal.
      final totalUnits = result.lines.fold<int>(
        0,
        (sum, l) => sum + l.lengthFt * l.allocatedPieces,
      );
      expect(totalUnits, 7);
      // Lower-length tie-break: the single 7 ft piece is NOT used while shorter
      // lengths can form the same sum.
      expect(result.lines.any((l) => l.lengthFt == 7), isFalse);
    });

    test('tie-break prefers lower length then lower stock id on equal excess',
        () {
      // Target just over one piece-length-unit so the smallest meet-or-exceed
      // length-unit sum is 2 (the shortest available length). per-piece = L/36;
      // target = 1/36 means thresholdUnits = ceil(1) = 1, and the smallest
      // reachable sum ≥ 1 using lengths {2,3} is 2 (a single 2 ft piece) — a
      // 3 ft piece would overshoot more, so lower length wins.
      final request = TargetCftFlexCrossSectionRequest(
        varietyId: 7,
        crossSectionId: plank4x1.id,
        targetCft: Rational(BigInt.from(1), BigInt.from(36)),
      );
      final result = service.allocateFlexiblePlank(
        request,
        [
          plankAt(99, 2, 3),
          plankAt(50, 3, 3),
        ],
      );

      expect(result.isPartial, isFalse);
      expect(result.lines, hasLength(1));
      expect(result.lines.single.lengthFt, 2); // lower length preferred
      expect(result.lines.single.allocatedPieces, 1);
    });

    test('duplicate rows at a length collapse and keep the lowest stock id',
        () {
      // Two rows at 2 ft (ids 70, 40) → one slot with 4 pieces, id 40.
      // Target 3/36 CFT → thresholdUnits = 3 → needs two 2 ft pieces (sum 4,
      // smallest ≥ 3 reachable with length 2).
      final request = TargetCftFlexCrossSectionRequest(
        varietyId: 7,
        crossSectionId: plank4x1.id,
        targetCft: Rational(BigInt.from(3), BigInt.from(36)),
      );
      final result = service.allocateFlexiblePlank(
        request,
        [
          plankAt(70, 2, 2),
          plankAt(40, 2, 2),
        ],
      );

      expect(result.isPartial, isFalse);
      expect(result.lines, hasLength(1));
      final line = result.lines.single;
      expect(line.lengthFt, 2);
      expect(line.stockItemId, 40); // lowest id kept
      expect(line.allocatedPieces, 2);
    });

    test('understock yields a labelled partial with the exact CFT shortage',
        () {
      // Only 2 pieces at 2 ft = 2 × 2/36 = 4/36 CFT available, target 1 CFT.
      // Allocates everything and reports the exact remaining shortage.
      final request = TargetCftFlexCrossSectionRequest(
        varietyId: 7,
        crossSectionId: plank4x1.id,
        targetCft: Rational.fromInt(1),
      );
      final result = service.allocateFlexiblePlank(
        request,
        [plankAt(10, 2, 2)],
      );

      expect(result.isPartial, isTrue);
      expect(result.isFullyAllocated, isFalse);
      expect(result.lines, hasLength(1));
      expect(result.lines.single.allocatedPieces, 2);
      expect(result.allocatedCft, calc.lineCftFor(plank4x1, 2, 2));
      expect(result.allocatedCft.value < request.targetCft, isTrue);
      // Shortage is exactly target − allocated.
      expect(
        result.shortageCft.value,
        request.targetCft - result.allocatedCft.value,
      );
    });

    test('no eligible stock → fully-unmet partial carrying the whole target',
        () {
      final request = TargetCftFlexCrossSectionRequest(
        varietyId: 7,
        crossSectionId: plank4x1.id,
        targetCft: Rational.fromInt(2),
      );
      final result = service.allocateFlexiblePlank(request, const []);

      expect(result.isPartial, isTrue);
      expect(result.lines, isEmpty);
      expect(result.allocatedCft, Cft.zero);
      expect(result.shortageCft.value, request.targetCft);
    });

    test('Req 21.13: a flexible plank allocation applies NO reaper 60/30/10 '
        'shares', () {
      // Give abundant stock ONLY at lengths that fall in reaper groups
      // ({6,7}=60%, {3,4,5}=30%, {2}=10%). A share-based allocator would spread
      // the target ≈60/30/10 across those groups. The plank min-excess fill
      // must instead meet-or-exceed with the fewest length-units (and never
      // touch share weights), so the CFT split does NOT follow 60/30/10.
      final request = TargetCftFlexCrossSectionRequest(
        varietyId: 7,
        crossSectionId: plank4x1.id,
        targetCft: Rational.fromInt(1), // 1 CFT = 36 length-units
      );
      final result = service.allocateFlexiblePlank(
        request,
        [
          plankAt(2, 2, 100),
          plankAt(3, 3, 100),
          plankAt(5, 5, 100),
          plankAt(6, 6, 100),
          plankAt(7, 7, 100),
        ],
      );

      expect(result.isPartial, isFalse);
      // thresholdUnits = ceil(1 × 144 / 4) = 36. The minimum length-unit sum
      // ≥ 36 reachable with lengths {2,3,5,6,7} is exactly 36 (e.g. 6×6 ft),
      // giving ZERO excess — a share-based 60/30/10 split could not do this.
      final totalUnits = result.lines.fold<int>(
        0,
        (sum, l) => sum + l.lengthFt * l.allocatedPieces,
      );
      expect(totalUnits, 36);
      expect(result.allocatedCft.value, request.targetCft); // exact, no excess

      // Prove the split is NOT the reaper 60/30/10 of allocated CFT. The 60%
      // group {6,7} would be ≈0.6 CFT; assert the actual {6,7} CFT share is
      // not pinned to that weighting (the fill concentrates on the min-excess
      // combination instead).
      final preferredCft = result.lines
          .where((l) => l.lengthFt == 6 || l.lengthFt == 7)
          .fold<Rational>(
            Rational.zero,
            (sum, l) => sum + l.allocatedCft.value,
          );
      final sixtyPercent =
          request.targetCft * Rational(BigInt.from(6), BigInt.from(10));
      expect(preferredCft == sixtyPercent, isFalse);
    });

    test('repeatable: identical inputs give an identical result', () {
      final request = TargetCftFlexCrossSectionRequest(
        varietyId: 7,
        crossSectionId: plank4x1.id,
        targetCft: Rational(BigInt.from(37), BigInt.from(36)),
      );
      final availability = [
        plankAt(10, 2, 4),
        plankAt(11, 3, 4),
        plankAt(12, 5, 4),
      ];

      final first = service.allocateFlexiblePlank(request, availability);
      final second = service.allocateFlexiblePlank(request, availability);

      expect(first.allocatedCft, second.allocatedCft);
      expect(first.isPartial, second.isPartial);
      expect(first.lines.length, second.lines.length);
      for (var i = 0; i < first.lines.length; i++) {
        expect(first.lines[i].lengthFt, second.lines[i].lengthFt);
        expect(first.lines[i].allocatedPieces, second.lines[i].allocatedPieces);
        expect(first.lines[i].stockItemId, second.lines[i].stockItemId);
      }
    });

    test('a reaper cross-section is rejected on the plank path', () {
      final request = TargetCftFlexCrossSectionRequest(
        varietyId: 7,
        crossSectionId: reaper2x1.id,
        targetCft: Rational.fromInt(5),
      );
      expect(
        () => service.allocateFlexiblePlank(
          request,
          [
            SkuAvailability(
              stockItemId: 100,
              crossSection: reaper2x1, // reaper, not plank
              lengthFt: 6,
              availablePieces: 100,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('cross-section mismatch is rejected', () {
      final request = TargetCftFlexCrossSectionRequest(
        varietyId: 7,
        crossSectionId: plank4x1.id,
        targetCft: Rational.fromInt(1),
      );
      final otherPlank = CrossSection(
        id: 9,
        widthIn: 5,
        thicknessIn: 1,
        category: WoodCategory.plank,
      );
      expect(
        () => service.allocateFlexiblePlank(
          request,
          [
            SkuAvailability(
              stockItemId: 300,
              crossSection: otherPlank, // id 9 ≠ request cross-section
              lengthFt: 6,
              availablePieces: 20,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('allocateExact — SKU consistency guards', () {
    test('cross-section mismatch is rejected', () {
      final request = ExactQtyRequest(
        varietyId: 7,
        crossSectionId: reaper2x1.id,
        lengthFt: 6,
        quantityUnits: 1,
      );
      final availability = SkuAvailability(
        stockItemId: 200,
        crossSection: plank4x1, // different cross-section
        lengthFt: 6,
        availablePieces: 10,
      );
      expect(
        () => service.allocateExact(request, availability),
        throwsArgumentError,
      );
    });

    test('length mismatch is rejected', () {
      final request = ExactQtyRequest(
        varietyId: 7,
        crossSectionId: reaper2x1.id,
        lengthFt: 6,
        quantityUnits: 1,
      );
      final availability = SkuAvailability(
        stockItemId: 100,
        crossSection: reaper2x1,
        lengthFt: 4, // different length
        availablePieces: 10,
      );
      expect(
        () => service.allocateExact(request, availability),
        throwsArgumentError,
      );
    });
  });

  group('allocateOrder — multi-line remaining availability (task 9.4)', () {
    // Req 21.14: when two order lines draw on the SAME stock item, the second
    // line only gets what the first left, the total allocated across lines
    // never exceeds that item's availability (no double count), and the later
    // line goes partial once the earlier line has consumed the stock.
    test(
        'two exact-qty lines on the same reaper SKU: second gets only the '
        'remainder and is a labelled partial (Req 21.14, Property 10)', () {
      // One reaper 2×1 @ 6 ft stock item with 5 bunches (50 pieces) confirmed.
      final availability = <SkuAvailability>[
        SkuAvailability(
          stockItemId: 100,
          crossSection: reaper2x1,
          lengthFt: 6,
          availablePieces: 50, // 5 bunches
        ),
      ];
      // Line 0 asks for 3 bunches, line 1 asks for 4 bunches — the SAME SKU.
      final requests = <OrderRequest>[
        ExactQtyRequest(
          varietyId: 7,
          crossSectionId: reaper2x1.id,
          lengthFt: 6,
          quantityUnits: 3,
        ),
        ExactQtyRequest(
          varietyId: 7,
          crossSectionId: reaper2x1.id,
          lengthFt: 6,
          quantityUnits: 4,
        ),
      ];

      final order = service.allocateOrder(requests, availability);

      // Line 0 is satisfied in full (3 bunches = 30 pieces).
      final line0 = order.lineResults[0];
      expect(line0.isPartial, isFalse);
      expect(line0.lines.single.allocatedUnits, 3);
      expect(line0.lines.single.allocatedPieces, 30);

      // Line 1 only sees the REMAINING 2 bunches (20 pieces) and is partial,
      // short exactly 2 bunches — it is NOT silently reduced.
      final line1 = order.lineResults[1];
      expect(line1.isPartial, isTrue);
      expect(line1.lines.single.allocatedUnits, 2);
      expect(line1.lines.single.allocatedPieces, 20);
      expect(line1.lines.single.shortageUnits, 2);

      // No double count: total pieces allocated from stock item 100 across all
      // lines never exceeds its availability (Property 10).
      final totalFrom100 = order.lines
          .where((l) => l.stockItemId == 100)
          .fold<int>(0, (sum, l) => sum + l.allocatedPieces);
      expect(totalFrom100, 50);
      expect(totalFrom100 <= 50, isTrue);

      // The order as a whole is a clearly-labelled partial (a line fell short),
      // never presented as fulfilled (Requirement 8.4).
      expect(order.isPartial, isTrue);
    });

    test(
        'later line goes partial when the earlier line consumed all the stock '
        '(no reuse across lines, Req 21.14)', () {
      final availability = <SkuAvailability>[
        SkuAvailability(
          stockItemId: 200,
          crossSection: plank4x1,
          lengthFt: 6,
          availablePieces: 10,
        ),
      ];
      // Line 0 consumes every piece; line 1 draws on the same SKU → shorted.
      final requests = <OrderRequest>[
        ExactQtyRequest(
          varietyId: 7,
          crossSectionId: plank4x1.id,
          lengthFt: 6,
          quantityUnits: 10,
        ),
        ExactQtyRequest(
          varietyId: 7,
          crossSectionId: plank4x1.id,
          lengthFt: 6,
          quantityUnits: 5,
        ),
      ];

      final order = service.allocateOrder(requests, availability);

      expect(order.lineResults[0].isPartial, isFalse);
      expect(order.lineResults[0].lines.single.allocatedPieces, 10);

      // Nothing is left for line 1 → fully-shorted partial, zero allocated.
      final line1 = order.lineResults[1];
      expect(line1.isPartial, isTrue);
      expect(line1.lines.single.allocatedPieces, 0);
      expect(line1.lines.single.shortageUnits, 5);

      final totalFrom200 = order.lines
          .where((l) => l.stockItemId == 200)
          .fold<int>(0, (sum, l) => sum + l.allocatedPieces);
      expect(totalFrom200, 10); // never exceeds availability
      expect(order.isPartial, isTrue);
    });

    test(
        'lines drawing on DIFFERENT stock items are each satisfied in full '
        '(independent availability)', () {
      final availability = <SkuAvailability>[
        SkuAvailability(
          stockItemId: 100,
          crossSection: reaper2x1,
          lengthFt: 6,
          availablePieces: 50,
        ),
        SkuAvailability(
          stockItemId: 200,
          crossSection: plank4x1,
          lengthFt: 6,
          availablePieces: 10,
        ),
      ];
      final requests = <OrderRequest>[
        ExactQtyRequest(
          varietyId: 7,
          crossSectionId: reaper2x1.id,
          lengthFt: 6,
          quantityUnits: 3,
        ),
        ExactQtyRequest(
          varietyId: 7,
          crossSectionId: plank4x1.id,
          lengthFt: 6,
          quantityUnits: 4,
        ),
      ];

      final order = service.allocateOrder(requests, availability);

      expect(order.isPartial, isFalse);
      expect(order.lineResults[0].lines.single.allocatedPieces, 30);
      expect(order.lineResults[1].lines.single.allocatedPieces, 4);
    });

    test('flexible reaper then exact line share one SKU without double count',
        () {
      // Two reaper 2×1 stock items at 6 ft and 7 ft.
      final availability = <SkuAvailability>[
        SkuAvailability(
          stockItemId: 100,
          crossSection: reaper2x1,
          lengthFt: 6,
          availablePieces: 30, // 3 bunches
        ),
        SkuAvailability(
          stockItemId: 101,
          crossSection: reaper2x1,
          lengthFt: 7,
          availablePieces: 30, // 3 bunches
        ),
      ];
      // Line 0: flexible-reaper target that draws bunches; line 1: exact-qty on
      // the 6 ft SKU, which must only see what the flexible line left.
      final requests = <OrderRequest>[
        TargetCftFlexCrossSectionRequest(
          varietyId: 7,
          crossSectionId: reaper2x1.id,
          targetCft: Rational.fromInt(3),
        ),
        ExactQtyRequest(
          varietyId: 7,
          crossSectionId: reaper2x1.id,
          lengthFt: 6,
          quantityUnits: 3,
        ),
      ];

      final order = service.allocateOrder(requests, availability);

      // No stock item is ever over-drawn across the two lines (Property 10).
      for (final id in <int>[100, 101]) {
        final avail = availability
            .firstWhere((a) => a.stockItemId == id)
            .availablePieces;
        final used = order.lines
            .where((l) => l.stockItemId == id)
            .fold<int>(0, (sum, l) => sum + l.allocatedPieces);
        expect(used <= avail, isTrue,
            reason: 'stock item $id over-drawn: $used > $avail');
      }
    });

    test('deterministic: identical inputs produce an identical result', () {
      final availability = <SkuAvailability>[
        SkuAvailability(
          stockItemId: 100,
          crossSection: reaper2x1,
          lengthFt: 6,
          availablePieces: 50,
        ),
      ];
      final requests = <OrderRequest>[
        ExactQtyRequest(
          varietyId: 7,
          crossSectionId: reaper2x1.id,
          lengthFt: 6,
          quantityUnits: 3,
        ),
        ExactQtyRequest(
          varietyId: 7,
          crossSectionId: reaper2x1.id,
          lengthFt: 6,
          quantityUnits: 4,
        ),
      ];

      final a = service.allocateOrder(requests, availability);
      final b = service.allocateOrder(requests, availability);
      expect(a.isPartial, b.isPartial);
      expect(a.lines.length, b.lines.length);
      for (var i = 0; i < a.lines.length; i++) {
        expect(a.lines[i].allocatedPieces, b.lines[i].allocatedPieces);
        expect(a.lines[i].allocatedCft, b.lines[i].allocatedCft);
      }
    });

    test('duplicate stock item in the snapshot is rejected', () {
      final availability = <SkuAvailability>[
        SkuAvailability(
          stockItemId: 100,
          crossSection: reaper2x1,
          lengthFt: 6,
          availablePieces: 50,
        ),
        SkuAvailability(
          stockItemId: 100, // duplicate id
          crossSection: reaper2x1,
          lengthFt: 7,
          availablePieces: 30,
        ),
      ];
      expect(
        () => service.allocateOrder(
          <OrderRequest>[
            ExactQtyRequest(
              varietyId: 7,
              crossSectionId: reaper2x1.id,
              lengthFt: 6,
              quantityUnits: 1,
            ),
          ],
          availability,
        ),
        throwsArgumentError,
      );
    });
  });
}
