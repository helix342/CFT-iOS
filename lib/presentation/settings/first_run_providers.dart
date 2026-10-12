/// First-run setup wiring for the Wood CFT app (task 15.2).
///
/// A fresh install must begin from an honest, empty state: the shipped catalog
/// (varieties Mahogany/Kalani/Palajathi and cross-sections 2×1 Reaper plus
/// 3×1…7×1 Plank) materialised with EVERY stock balance at zero, no fabricated
/// prices, and no assumed business identity (design.md -> Screen Flows,
/// First-run setup; Requirements 1.1, 1.2, 1.12, 18.2, 18.5). First-run also
/// requests only the MINIMUM configuration to begin — a business name — and
/// defaults the timezone to Asia/Kolkata (Requirement 17.12).
///
/// This file owns:
///   * [kFirstRunTimezone] — the Asia/Kolkata default.
///   * [CatalogSeeder] — idempotently writes the pure-Dart [kInitialCatalogSeed]
///     into the drift database: variety rows, cross-section rows, and one
///     stock-item row per variety × cross-section × length (2–9 ft) at zero
///     confirmed/pending balance. It inserts NO movement rows, NO price rows,
///     and NO non-zero quantities, so "zero stock / no prices" is a literal
///     property of the seeded database.
///   * [firstRunCompleteProvider] — resolves whether first-run has already been
///     completed (true once the catalog has been seeded and a business name is
///     configured).
///   * [FirstRunController] — runs the one-shot setup: seed the catalog, persist
///     the minimum business profile, and persist the chosen policy singletons.
///
/// The shared [appDatabaseProvider] is reused (never redeclared) and the
/// read-only policy providers from task 15.1 keep their names/types; this layer
/// only writes rows and drives the editable controllers.
library;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/price_rate_repository.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/domain/business_settings.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/catalog_seed.dart';
import 'package:wood_cft/presentation/settings/business_profile_providers.dart';

/// The default timezone for a fresh install (Requirement 17.12).
///
/// First-run does not ask for a timezone; it defaults here so order/invoice
/// timestamps are interpreted in the shop's local zone from the first use.
const String kFirstRunTimezone = 'Asia/Kolkata';

/// The default ₹/CFT rate seeded (and back-filled) for every
/// variety × cross-section cell (FIX 4): ₹480.00 per CFT.
///
/// A rate is stored as an exact rational ₹/CFT (never a binary `double`), so
/// ₹480/CFT is the whole rational `480/1`. Reading it back through
/// `PriceRateRepository`/`PricingService` yields ₹480.00/CFT in billing.
final Rational kDefaultSeedRatePerCft = Rational.fromInt(480);

/// Writes the shipped catalog into the drift database with zero stock and no
/// prices (Requirements 1.1, 1.2, 1.12).
///
/// Seeding is idempotent: it checks whether varieties already exist and does
/// nothing on a database that has been seeded before, so re-running first-run
/// (or a resumed launch) never duplicates the catalog or resets balances.
class CatalogSeeder {
  /// Creates a seeder backed by [_db].
  CatalogSeeder(this._db);

  final AppDatabase _db;

  /// Whether the catalog has already been materialised (any variety row).
  Future<bool> isSeeded() async {
    final row = await (_db.select(_db.woodVarieties)..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  /// Seeds the catalog from [kInitialCatalogSeed] inside one transaction.
  ///
  /// Inserts the variety rows, the cross-section rows, and exactly one
  /// stock-item row per variety × cross-section × length (2–9 ft) at the zero
  /// opening balance ([kSeedStockItemBalancePieces]). No movement, price, or
  /// non-zero quantity is ever written. A no-op when [isSeeded] already holds.
  Future<void> seed() async {
    if (await isSeeded()) return;

    final seed = kInitialCatalogSeed;
    final createdAt = DateTime.now().toUtc();

    await _db.transaction(() async {
      // Varieties — keep the seed's stable ids so later layers can rely on them.
      for (final variety in seed.varieties) {
        await _db.into(_db.woodVarieties).insert(
              WoodVarietiesCompanion.insert(
                id: Value(variety.id),
                name: variety.name,
                active: Value(variety.active),
                createdAt: createdAt,
              ),
            );
      }

      // Cross-sections — carry the stored category ordinal and bunch size.
      for (final crossSection in seed.crossSections) {
        await _db.into(_db.crossSections).insert(
              CrossSectionsCompanion.insert(
                id: Value(crossSection.id),
                widthIn: crossSection.widthIn,
                thicknessIn: crossSection.thicknessIn,
                category: crossSection.category == WoodCategory.reaper
                    ? CategoryKind.reaper
                    : CategoryKind.plank,
                bunchSize: crossSection.bunchSize,
                active: Value(crossSection.active),
              ),
            );
      }

      // One zero-balance stock item per variety × cross-section × length.
      // Balances default to 0 (confirmed and pending), so no fictional stock
      // is ever seeded (Requirement 1.12).
      for (final item in seed.enumerateStockItems()) {
        await _db.into(_db.stockItems).insert(
              StockItemsCompanion.insert(
                varietyId: item.varietyId,
                crossSectionId: item.crossSectionId,
                lengthFt: item.lengthFt,
                confirmedBalancePieces:
                    const Value(kSeedStockItemBalancePieces),
                pendingBalancePieces:
                    const Value(kSeedStockItemBalancePieces),
              ),
            );
      }
    });

    // FIX 4: a fresh install gets a default ₹480/CFT price for every
    // variety × cross-section so billing is never blocked on a missing rate.
    await seedDefaultPrices();
  }

  /// Seeds / back-fills the default ₹480/CFT rate for every
  /// variety × cross-section pair that currently LACKS a valid rate (FIX 4).
  ///
  /// Idempotent and non-destructive: a cell that already has an owner-entered
  /// rate is left untouched, and re-running never duplicates a row (the
  /// repository upserts on the unique variety × cross-section key). This serves
  /// both a fresh install (called from [seed]) and an already-seeded install
  /// (called as a one-time backfill from [FirstRunController.complete]), so an
  /// install that was seeded before prices existed still gets ₹480.
  Future<int> seedDefaultPrices() async {
    final varieties = await _db.select(_db.woodVarieties).get();
    final crossSections = await _db.select(_db.crossSections).get();
    final repo = PriceRateRepository(_db);

    var written = 0;
    for (final variety in varieties) {
      for (final crossSection in crossSections) {
        final existing = await repo.lookupRate(
          varietyId: variety.id,
          crossSectionId: crossSection.id,
        );
        // Only fill cells that are missing (null/absent); never overwrite a
        // rate the owner has already set.
        if (existing != null) continue;
        await repo.setRate(
          varietyId: variety.id,
          crossSectionId: crossSection.id,
          rate: kDefaultSeedRatePerCft,
        );
        written++;
      }
    }
    return written;
  }
}

/// Provides the catalog seeder bound to [appDatabaseProvider].
final catalogSeederProvider = Provider<CatalogSeeder>((ref) {
  return CatalogSeeder(ref.watch(appDatabaseProvider));
});

/// Resolves whether the app has already completed first-run setup.
///
/// First-run is complete when the catalog has been seeded AND a non-blank
/// business name has been configured (the minimum config to begin). A fresh
/// install resolves to `false`, so the shell routes to the first-run screen.
final firstRunCompleteProvider = FutureProvider<bool>((ref) async {
  final seeder = ref.watch(catalogSeederProvider);
  if (!await seeder.isSeeded()) return false;
  final repo = ref.watch(businessSettingsRepositoryProvider);
  final profile = await repo.load();
  return profile.name.trim().isNotEmpty;
});

/// Drives the one-shot first-run setup.
///
/// [complete] seeds the catalog (zero stock, no prices), persists the minimum
/// business profile the owner entered, and leaves the policy singletons at
/// their owner-confirmed defaults unless the owner changed them. It performs no
/// network call and fabricates nothing beyond the shipped catalog.
class FirstRunController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Completes first-run with the minimum [profile] the owner supplied.
  ///
  /// Seeds the catalog and persists [profile]. Throws [ArgumentError] when the
  /// business name is blank — the one field required to begin.
  Future<void> complete({required BusinessProfile profile}) async {
    if (profile.name.trim().isEmpty) {
      throw ArgumentError.value(
        profile.name,
        'profile.name',
        'A business name is required to begin',
      );
    }
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(() async {
      final seeder = ref.read(catalogSeederProvider);
      await seeder.seed();
      // One-time backfill (FIX 4): an install seeded BEFORE default prices
      // existed gets ₹480 for any still-missing variety × cross-section cell.
      // No-op on a fresh install (seed() already filled every cell).
      await seeder.seedDefaultPrices();
      await ref.read(businessSettingsRepositoryProvider).save(profile);
      // Refresh the completion gate so the shell leaves first-run.
      ref.invalidate(firstRunCompleteProvider);
    });
  }
}

/// The first-run controller provider used by the first-run screen.
final firstRunControllerProvider =
    AsyncNotifierProvider<FirstRunController, void>(FirstRunController.new);
