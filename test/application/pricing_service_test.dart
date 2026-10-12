/// Unit tests for the price-matrix service (task 7.1).
///
/// These boot an in-memory [AppDatabase] (so they run under `flutter test` on
/// Windows with no device) and exercise [PricingService] over the real
/// [PriceRateRepository]:
///
///   * a rate is independent of length — the lookup API takes no length and the
///     same stored rate applies to every length (Req 4.2; CD-2);
///   * adding a variety scaffolds EMPTY (null) rate cells, never a guessed
///     value (Req 4.4);
///   * the missing-rate query lists exactly the unpriced pairs (Req 4.5);
///   * setting then reading a rate round-trips the exact rational (Req 4.1).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/pricing_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/price_rate_repository.dart';
import 'package:wood_cft/data/tables.dart';

/// Inserts a variety and returns its id.
Future<int> _seedVariety(AppDatabase db, String name) {
  return db.into(db.woodVarieties).insert(
        WoodVarietiesCompanion.insert(
          name: name,
          createdAt: DateTime.utc(2024, 1, 1),
        ),
      );
}

/// Inserts a cross-section and returns its id.
Future<int> _seedCrossSection(
  AppDatabase db, {
  required int widthIn,
  required int thicknessIn,
  CategoryKind category = CategoryKind.plank,
  int bunchSize = 1,
}) {
  return db.into(db.crossSections).insert(
        CrossSectionsCompanion.insert(
          widthIn: widthIn,
          thicknessIn: thicknessIn,
          category: category,
          bunchSize: bunchSize,
        ),
      );
}

void main() {
  group('PricingService — rate storage and missing-rate detection', () {
    late AppDatabase db;
    late PriceRateRepository repository;
    late PricingService pricing;

    setUp(() async {
      db = openInMemoryDatabase();
      repository = PriceRateRepository(db);
      pricing = PricingService(repository);
    });

    tearDown(() async {
      await db.close();
    });

    test(
        'a rate is independent of length: the API takes no length and the '
        'stored row carries none (Req 4.2)', () async {
      final varietyId = await _seedVariety(db, 'Mahogany');
      final crossSectionId = await _seedCrossSection(
        db,
        widthIn: 3,
        thicknessIn: 1,
      );

      final rate = Rational(BigInt.from(1500), BigInt.one); // ₹1500/CFT
      await pricing.setRate(
        varietyId: varietyId,
        crossSectionId: crossSectionId,
        rate: rate,
      );

      // The lookup signature has no length parameter — the single stored rate
      // is returned for the variety × cross-section regardless of length.
      final looked = await pricing.rateFor(
        varietyId: varietyId,
        crossSectionId: crossSectionId,
      );
      expect(looked, rate);

      // The persisted row itself carries no length: the price matrix has
      // exactly one row for this variety × cross-section.
      final rows = await db.select(db.priceRates).get();
      expect(rows, hasLength(1));
      expect(rows.single.varietyId, varietyId);
      expect(rows.single.crossSectionId, crossSectionId);
      // `PriceRateRow` has width/thickness-independent key columns only; there
      // is no `lengthFt` field to read, proving length is not part of the key.
    });

    test(
        'adding a variety scaffolds empty (null) rate cells, not guessed '
        'values (Req 4.4)', () async {
      final varietyId = await _seedVariety(db, 'Kalani');
      final csA = await _seedCrossSection(db, widthIn: 2, thicknessIn: 1);
      final csB = await _seedCrossSection(db, widthIn: 4, thicknessIn: 1);
      final csC = await _seedCrossSection(db, widthIn: 6, thicknessIn: 1);

      final created = await pricing.onVarietyAdded(
        varietyId: varietyId,
        crossSectionIds: [csA, csB, csC],
      );
      expect(created, 3);

      // Every scaffolded cell is MISSING — no rate was inferred.
      for (final csId in [csA, csB, csC]) {
        expect(
          await pricing.rateFor(varietyId: varietyId, crossSectionId: csId),
          isNull,
        );
      }

      // Re-scaffolding is a no-op: it never clears or overwrites existing cells.
      await pricing.setRate(
        varietyId: varietyId,
        crossSectionId: csA,
        rate: Rational.fromInt(1200),
      );
      final createdAgain = await pricing.onVarietyAdded(
        varietyId: varietyId,
        crossSectionIds: [csA, csB, csC],
      );
      expect(createdAgain, 0);
      expect(
        await pricing.rateFor(varietyId: varietyId, crossSectionId: csA),
        Rational.fromInt(1200),
      );
    });

    test('missing-rate query lists exactly the unpriced pairs (Req 4.5)',
        () async {
      final mahogany = await _seedVariety(db, 'Mahogany');
      final kalani = await _seedVariety(db, 'Kalani');
      final cs2x1 = await _seedCrossSection(db, widthIn: 2, thicknessIn: 1);
      final cs3x1 = await _seedCrossSection(db, widthIn: 3, thicknessIn: 1);

      // Scaffold a full 2×2 matrix: 4 empty cells.
      await pricing.onVarietyAdded(
        varietyId: mahogany,
        crossSectionIds: [cs2x1, cs3x1],
      );
      await pricing.onVarietyAdded(
        varietyId: kalani,
        crossSectionIds: [cs2x1, cs3x1],
      );

      // Price two of the four cells.
      await pricing.setRate(
        varietyId: mahogany,
        crossSectionId: cs2x1,
        rate: Rational.fromInt(1500),
      );
      await pricing.setRate(
        varietyId: kalani,
        crossSectionId: cs3x1,
        rate: Rational.fromInt(1800),
      );

      final missing = await pricing.missingRates();

      // Exactly the two still-unpriced pairs, no more and no fewer.
      expect(missing.toSet(), {
        MissingRate(varietyId: mahogany, crossSectionId: cs3x1),
        MissingRate(varietyId: kalani, crossSectionId: cs2x1),
      });
    });

    test('clearing a priced cell makes it missing again (Req 4.5)', () async {
      final varietyId = await _seedVariety(db, 'Palajathi');
      final crossSectionId = await _seedCrossSection(
        db,
        widthIn: 5,
        thicknessIn: 1,
      );

      await pricing.setRate(
        varietyId: varietyId,
        crossSectionId: crossSectionId,
        rate: Rational.fromInt(1700),
      );
      expect(
        await pricing.hasRate(
          varietyId: varietyId,
          crossSectionId: crossSectionId,
        ),
        isTrue,
      );
      expect(await pricing.missingRates(), isEmpty);

      await pricing.clearRate(
        varietyId: varietyId,
        crossSectionId: crossSectionId,
      );
      expect(
        await pricing.rateFor(
          varietyId: varietyId,
          crossSectionId: crossSectionId,
        ),
        isNull,
      );
      expect(await pricing.missingRates(), [
        MissingRate(varietyId: varietyId, crossSectionId: crossSectionId),
      ]);
    });

    test(
        'setting then reading a rate round-trips the exact rational (Req 4.1)',
        () async {
      final varietyId = await _seedVariety(db, 'Mahogany');
      final crossSectionId = await _seedCrossSection(
        db,
        widthIn: 7,
        thicknessIn: 1,
      );

      // A non-terminating decimal rate: 5000/3 ₹/CFT (= ₹1666.666.../CFT).
      // Storing as num/den keeps it exact — no binary-float drift.
      final rate = Rational(BigInt.from(5000), BigInt.from(3));
      await pricing.setRate(
        varietyId: varietyId,
        crossSectionId: crossSectionId,
        rate: rate,
      );

      final looked = await pricing.rateFor(
        varietyId: varietyId,
        crossSectionId: crossSectionId,
      );
      expect(looked, rate);
      // Exactly equal: numerator and denominator both preserved.
      expect(looked!.numerator, BigInt.from(5000));
      expect(looked.denominator, BigInt.from(3));
    });

    test('setRate updates an existing cell in place (one row per pair)',
        () async {
      final varietyId = await _seedVariety(db, 'Kalani');
      final crossSectionId = await _seedCrossSection(
        db,
        widthIn: 2,
        thicknessIn: 1,
        category: CategoryKind.reaper,
        bunchSize: 10,
      );

      await pricing.setRate(
        varietyId: varietyId,
        crossSectionId: crossSectionId,
        rate: Rational.fromInt(1000),
      );
      await pricing.setRate(
        varietyId: varietyId,
        crossSectionId: crossSectionId,
        rate: Rational.fromInt(1250),
      );

      final rows = await db.select(db.priceRates).get();
      expect(rows, hasLength(1));
      expect(
        await pricing.rateFor(
          varietyId: varietyId,
          crossSectionId: crossSectionId,
        ),
        Rational.fromInt(1250),
      );
    });

    test('a non-positive rate is rejected without a write', () async {
      final varietyId = await _seedVariety(db, 'Mahogany');
      final crossSectionId = await _seedCrossSection(
        db,
        widthIn: 3,
        thicknessIn: 1,
      );

      expect(
        () => pricing.setRate(
          varietyId: varietyId,
          crossSectionId: crossSectionId,
          rate: Rational.zero,
        ),
        throwsArgumentError,
      );
      // Nothing was written.
      expect(await db.select(db.priceRates).get(), isEmpty);
    });
  });
}
