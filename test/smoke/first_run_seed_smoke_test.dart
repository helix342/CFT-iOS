/// First-run seed smoke check (task 17.4).
///
/// Verifies that first-run seeding materialises an honest, empty starting
/// state: the shipped catalog (Mahogany/Kalani/Palajathi × 2×1 Reaper +
/// 3×1…7×1 Plank × lengths 2–9 ft) with EVERY stock balance at zero and nothing
/// fictional — and that re-running the seed is idempotent. Prices are seeded at
/// the default ₹480/CFT for every variety × cross-section (FIX 4).
///
/// Validates: Requirements 1.1 (varieties), 1.2 (cross-sections), 1.12 (zero
/// stock); FIX 4 (default ₹480/CFT prices seeded + idempotent backfill).
///
/// Runs headless on Windows via an in-memory drift database
/// ([openInMemoryDatabase]); no device, file, or network is touched.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/price_rate_repository.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/catalog_seed.dart';
import 'package:wood_cft/presentation/settings/first_run_providers.dart';

void main() {
  late AppDatabase db;
  late CatalogSeeder seeder;

  setUp(() {
    db = openInMemoryDatabase();
    seeder = CatalogSeeder(db);
  });

  tearDown(() async {
    await db.close();
  });

  // Lengths 2–9 ft inclusive, as enumerated by the catalog seed.
  final expectedLengths = <int>[
    for (var l = kMinLengthFt; l <= kMaxLengthFt; l++) l,
  ];
  final expectedStockItemCount = kSeedVarieties.length *
      kSeedCrossSections.length *
      expectedLengths.length;

  test('a fresh database starts unseeded', () async {
    expect(await seeder.isSeeded(), isFalse);

    expect(await db.select(db.woodVarieties).get(), isEmpty);
    expect(await db.select(db.crossSections).get(), isEmpty);
    expect(await db.select(db.stockItems).get(), isEmpty);
    expect(await db.select(db.priceRates).get(), isEmpty);
  });

  test('seeding materialises exactly the shipped varieties (Req 1.1)',
      () async {
    await seeder.seed();

    final varieties = await db.select(db.woodVarieties).get();
    expect(
      varieties.map((v) => v.name).toList(),
      <String>['Mahogany', 'Kalani', 'Palajathi'],
      reason: 'the catalog must ship exactly the three named varieties',
    );
    // Nothing fictional: every seeded variety is active and nothing extra.
    expect(varieties.every((v) => v.active), isTrue);
    expect(varieties.length, kSeedVarieties.length);
  });

  test('seeding materialises exactly the shipped cross-sections (Req 1.2)',
      () async {
    await seeder.seed();

    final sections = await db.select(db.crossSections).get();
    // 2×1 Reaper plus 3×1,4×1,5×1,6×1,7×1 Plank.
    final profiles = sections
        .map((s) => '${s.widthIn}x${s.thicknessIn}:${s.category.name}')
        .toList()
      ..sort();
    expect(profiles, <String>[
      '2x1:reaper',
      '3x1:plank',
      '4x1:plank',
      '5x1:plank',
      '6x1:plank',
      '7x1:plank',
    ]);
    expect(sections.length, kSeedCrossSections.length);
  });

  test(
      'seeding creates one zero-balance stock item per variety×section×length '
      'with NO non-zero stock (Req 1.12)', () async {
    await seeder.seed();

    final items = await db.select(db.stockItems).get();

    // One row per combination — nothing missing, nothing fabricated.
    expect(items.length, expectedStockItemCount);

    // EVERY balance (confirmed and pending) is literally zero.
    expect(
      items.every((i) =>
          i.confirmedBalancePieces == 0 && i.pendingBalancePieces == 0),
      isTrue,
      reason: 'first-run must seed zero stock — no fictional quantities',
    );

    // Lengths are confined to the 2–9 ft grid.
    final lengths = items.map((i) => i.lengthFt).toSet().toList()..sort();
    expect(lengths, expectedLengths);
  });

  test('seeding writes NO movement rows (Req 1.12)', () async {
    await seeder.seed();

    expect(
      await db.select(db.stockMovements).get(),
      isEmpty,
      reason: 'no ledger movements are fabricated on first run',
    );
  });

  test('seeding sets a default ₹480/CFT rate for every variety×section (FIX 4)',
      () async {
    await seeder.seed();

    final rows = await db.select(db.priceRates).get();
    // One priced cell per variety × cross-section (length-independent).
    expect(
      rows.length,
      kSeedVarieties.length * kSeedCrossSections.length,
    );

    // Every cell reads back as exactly ₹480.00/CFT.
    final repo = PriceRateRepository(db);
    for (final variety in kSeedVarieties) {
      for (final crossSection in kSeedCrossSections) {
        final rate = await repo.lookupRate(
          varietyId: variety.id,
          crossSectionId: crossSection.id,
        );
        expect(rate, Rational.fromInt(480));
      }
    }
  });

  test('re-seeding default prices is idempotent and never overwrites an '
      'owner-entered rate (FIX 4)', () async {
    await seeder.seed();

    // Owner edits one cell to a custom rate.
    final repo = PriceRateRepository(db);
    final v = kSeedVarieties.first.id;
    final cs = kSeedCrossSections.first.id;
    await repo.setRate(
      varietyId: v,
      crossSectionId: cs,
      rate: Rational.fromInt(999),
    );

    // A backfill re-run must NOT reset the owner's rate and must not duplicate.
    final written = await seeder.seedDefaultPrices();
    expect(written, 0, reason: 'every cell already has a rate');

    final rows = await db.select(db.priceRates).get();
    expect(rows.length, kSeedVarieties.length * kSeedCrossSections.length);
    expect(
      await repo.lookupRate(varietyId: v, crossSectionId: cs),
      Rational.fromInt(999),
    );
  });

  test('seedDefaultPrices back-fills an install seeded before prices existed '
      '(FIX 4)', () async {
    // Simulate an older install: catalog present but every price cell absent.
    await seeder.seed();
    await db.delete(db.priceRates).go();
    expect(await db.select(db.priceRates).get(), isEmpty);

    final written = await seeder.seedDefaultPrices();
    expect(written, kSeedVarieties.length * kSeedCrossSections.length);

    final repo = PriceRateRepository(db);
    final rate = await repo.lookupRate(
      varietyId: kSeedVarieties.first.id,
      crossSectionId: kSeedCrossSections.first.id,
    );
    expect(rate, Rational.fromInt(480));
  });

  test('seeding is idempotent — re-running changes nothing', () async {
    await seeder.seed();
    expect(await seeder.isSeeded(), isTrue);

    final varietiesAfterFirst = await db.select(db.woodVarieties).get();
    final sectionsAfterFirst = await db.select(db.crossSections).get();
    final itemsAfterFirst = await db.select(db.stockItems).get();

    // Second (and third) seed must be a no-op.
    await seeder.seed();
    await seeder.seed();

    expect(
      (await db.select(db.woodVarieties).get()).length,
      varietiesAfterFirst.length,
    );
    expect(
      (await db.select(db.crossSections).get()).length,
      sectionsAfterFirst.length,
    );

    final itemsAfterRepeat = await db.select(db.stockItems).get();
    expect(itemsAfterRepeat.length, itemsAfterFirst.length);

    // Balances are still all zero — a re-seed never resets or inflates stock.
    expect(
      itemsAfterRepeat.every((i) =>
          i.confirmedBalancePieces == 0 && i.pendingBalancePieces == 0),
      isTrue,
    );
    // Prices stay at exactly one ₹480 cell per variety × cross-section; a
    // re-seed never duplicates them (FIX 4).
    expect(
      (await db.select(db.priceRates).get()).length,
      kSeedVarieties.length * kSeedCrossSections.length,
    );
  });
}
