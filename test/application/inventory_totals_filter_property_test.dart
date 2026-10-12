// Property-based test for Property 23 (task 6.3).
//
// Property 23 - Inventory totals equal the sum over the active filter
// (design.md -> Correctness Properties; Requirements 6.1, 6.3):
//
//   "For all inventories and filter selections, the displayed total CFT equals
//    the sum of the exact available CFT of exactly the items that pass the
//    filter."
//
// This drives the REAL DB-backed `InventoryQueryService` end to end: for each
// generated iteration it boots a fresh in-memory `AppDatabase`
// (`openInMemoryDatabase`, so it runs under `flutter test` on Windows with no
// device), seeds a random catalog + a random inventory of stock items with
// mixed confirmed/pending balances, picks a random `InventoryFilter`, and runs
// `InventoryQueryService.query`.
//
// For every generated (inventory, filter) it asserts, over >= 150 iterations:
//
//   1. Sum-over-the-filter: the reported `totalAvailableCft` equals the exact
//      unrounded sum of the available (CONFIRMED-only) CFT of exactly the rows
//      that pass the filter, computed independently as a `Rational`. The
//      integer `totalAvailablePieces` likewise equals the sum of the passing
//      rows' confirmed pieces.
//   2. Order independence: shuffling the matching rows' available CFT and
//      re-summing yields the exact same total (the engine's exact-rational sum
//      cannot depend on iteration order).
//   3. Excluded items never contribute: every stock item the filter rejects
//      (wrong variety / category / cross-section / length, or zero-confirmed
//      when zero-stock is hidden) is absent from the rows AND its CFT is not
//      part of the total. Equivalently, re-adding every excluded item's exact
//      CFT to the reported total reproduces the whole-inventory confirmed CFT.
//   4. Zero-stock toggle consistency: hiding zero-stock drops exactly the rows
//      whose CONFIRMED balance is zero and nothing else, so the hidden total
//      equals the shown total minus those (always-zero) rows — i.e. the two
//      totals are equal, and the hidden row set is the shown set minus the
//      zero-confirmed rows.
//
// PBT framework: `package:glados`. `ExploreConfig(numRuns:, random:)` fixes the
// iteration count (>= 150) and seeds a deterministic `Random` so a
// counterexample reproduces exactly. Glados re-exports `package:test`; the test
// body is async because the query hits an in-memory database.
//
// This test does NOT edit production source and reuses the in-memory drift DB
// exactly as the task-6.1 unit tests do.

import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:glados/glados.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/application/inventory_query_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/cft.dart';

/// The single shared engine the service routes every CFT through.
const CalculationService _calc = CalculationService();

/// Deterministic exploration config giving the property >= 150 iterations from
/// a fixed seed (so a failure reproduces exactly).
final ExploreConfig _explore =
    ExploreConfig(numRuns: 180, random: Random(20240613));

/// A generated cross-section spec (dimensions + category). Bunch size is
/// derived from the category, matching the catalog rules.
class _CrossSpec {
  const _CrossSpec(this.widthIn, this.thicknessIn, this.isReaper);

  final int widthIn;
  final int thicknessIn;
  final bool isReaper;

  CategoryKind get categoryKind =>
      isReaper ? CategoryKind.reaper : CategoryKind.plank;

  WoodCategory get domainCategory =>
      isReaper ? WoodCategory.reaper : WoodCategory.plank;

  int get bunchSize => isReaper ? 10 : 1;

  @override
  String toString() =>
      '_CrossSpec(${widthIn}x$thicknessIn, '
      '${isReaper ? 'reaper' : 'plank'})';
}

/// A generated stock item: indexes into the generated variety/cross-section
/// pools (taken modulo the pool size at seed time), a catalog length (2..9 ft),
/// and confirmed/pending piece balances.
class _StockSpec {
  const _StockSpec(
    this.varietyIndex,
    this.crossIndex,
    this.lengthFt,
    this.confirmed,
    this.pending,
  );

  final int varietyIndex;
  final int crossIndex;
  final int lengthFt;
  final int confirmed;
  final int pending;

  @override
  String toString() =>
      '_StockSpec(v$varietyIndex, x$crossIndex, l$lengthFt, '
      'c$confirmed, p$pending)';
}

/// A generated filter selection. Each dimension is nullable (null = no
/// constraint); the concrete variety/cross-section/category/length are chosen
/// from small ranges that overlap the generated pools so the filter sometimes
/// matches and sometimes does not.
class _FilterSpec {
  const _FilterSpec(
    this.varietyIndex,
    this.crossIndex,
    this.useReaperCategory,
    this.useCategory,
    this.lengthFt,
    this.includeZeroStock,
  );

  final int? varietyIndex;
  final int? crossIndex;
  final bool useReaperCategory;
  final bool useCategory;
  final int? lengthFt;
  final bool includeZeroStock;

  @override
  String toString() =>
      '_FilterSpec(v$varietyIndex, x$crossIndex, '
      'cat=${useCategory ? (useReaperCategory ? 'reaper' : 'plank') : 'any'}, '
      'l$lengthFt, zero=$includeZeroStock)';
}

/// A whole generated scenario: the variety/cross-section pools, the inventory,
/// and the filter.
class _Scenario {
  const _Scenario(
    this.varietyCount,
    this.crossSpecs,
    this.stockSpecs,
    this.filter,
  );

  final int varietyCount;
  final List<_CrossSpec> crossSpecs;
  final List<_StockSpec> stockSpecs;
  final _FilterSpec filter;

  @override
  String toString() =>
      '_Scenario(varieties: $varietyCount, cross: $crossSpecs, '
      'stock: $stockSpecs, filter: $filter)';
}

/// Generator for one cross-section: width 1..12 in, thickness 1..6 in, and a
/// reaper/plank flag.
final Generator<_CrossSpec> _crossGen = any.combine3(
  any.intInRange(1, 13),
  any.intInRange(1, 7),
  any.bool,
  _CrossSpec.new,
);

/// Generator for one stock item. The variety/cross indices are 0..9 and reduced
/// modulo the actual pool sizes at seed time, so they always reference a real
/// seeded row. Confirmed/pending balances include zero (to exercise the
/// zero-stock toggle and pending-only items).
final Generator<_StockSpec> _stockGen = any.combine5(
  any.intInRange(0, 10),
  any.intInRange(0, 10),
  any.intInRange(2, 10), // lengthFt 2..9
  any.intInRange(0, 60), // confirmed 0..59
  any.intInRange(0, 40), // pending 0..39
  _StockSpec.new,
);

/// Generator for the filter selection. Nullable dimensions are modelled as an
/// index with a "disabled" sentinel: an out-of-range index (encoded as -1)
/// means "no constraint on that dimension".
/// Candidate length-constraint values, indexed by [_FilterSpec]'s length code:
/// index 0 means "no length constraint" (null), the rest are catalog lengths.
const List<int?> _lengthChoices = <int?>[null, 2, 4, 6, 9];

final Generator<_FilterSpec> _filterGen = any.combine6(
  any.intInRange(-1, 4), // varietyIndex: -1 => no constraint, else 0..3
  any.intInRange(-1, 4), // crossIndex:   -1 => no constraint, else 0..3
  any.bool, // reaper vs plank when category constraint is on
  any.bool, // whether to constrain by category at all
  any.intInRange(0, 5), // length choice index into _lengthChoices
  any.bool, // includeZeroStock
  (v, x, reaper, useCat, lenIdx, zero) => _FilterSpec(
    v < 0 ? null : v,
    x < 0 ? null : x,
    reaper,
    useCat,
    _lengthChoices[lenIdx],
    zero,
  ),
);

/// Generator for a whole scenario: 1..4 varieties, 1..4 cross-sections, 0..20
/// stock items, and a filter.
final Generator<_Scenario> _scenarioGen = any.combine4(
  any.intInRange(1, 5), // varietyCount 1..4
  any.listWithLengthInRange(1, 5, _crossGen), // 1..4 cross-sections
  any.listWithLengthInRange(0, 21, _stockGen), // 0..20 stock items
  _filterGen,
  _Scenario.new,
);

/// Seeds [scenario] into a fresh in-memory database and returns the service
/// plus the lookup tables needed to compute the expected totals independently.
Future<_SeededWorld> _seed(_Scenario scenario) async {
  final db = openInMemoryDatabase();

  // Varieties.
  final varietyIds = <int>[];
  for (var i = 0; i < scenario.varietyCount; i++) {
    final id = await db.into(db.woodVarieties).insert(
          WoodVarietiesCompanion.insert(
            name: 'V$i',
            createdAt: DateTime.utc(2024, 1, 1),
          ),
        );
    varietyIds.add(id);
  }

  // Cross-sections (domain projection kept for expected CFT).
  final crossIds = <int>[];
  final crossDomains = <CrossSection>[];
  for (final spec in scenario.crossSpecs) {
    final id = await db.into(db.crossSections).insert(
          CrossSectionsCompanion.insert(
            widthIn: spec.widthIn,
            thicknessIn: spec.thicknessIn,
            category: spec.categoryKind,
            bunchSize: spec.bunchSize,
          ),
        );
    crossIds.add(id);
    crossDomains.add(
      CrossSection(
        id: id,
        widthIn: spec.widthIn,
        thicknessIn: spec.thicknessIn,
        category: spec.domainCategory,
      ),
    );
  }

  // Stock items. The business key (variety, cross-section, length) is unique,
  // so we skip any generated duplicate rather than let the insert throw — the
  // kept set is still a valid random inventory.
  final seen = <String>{};
  final seededStock = <_SeededStock>[];
  for (final spec in scenario.stockSpecs) {
    final vIdx = spec.varietyIndex % varietyIds.length;
    final xIdx = spec.crossIndex % crossIds.length;
    final key = '$vIdx|$xIdx|${spec.lengthFt}';
    if (!seen.add(key)) continue;

    final stockId = await db.into(db.stockItems).insert(
          StockItemsCompanion.insert(
            varietyId: varietyIds[vIdx],
            crossSectionId: crossIds[xIdx],
            lengthFt: spec.lengthFt,
            confirmedBalancePieces: Value(spec.confirmed),
            pendingBalancePieces: Value(spec.pending),
          ),
        );
    seededStock.add(
      _SeededStock(
        stockId: stockId,
        varietyId: varietyIds[vIdx],
        crossSectionId: crossIds[xIdx],
        crossDomain: crossDomains[xIdx],
        isReaper: scenario.crossSpecs[xIdx].isReaper,
        lengthFt: spec.lengthFt,
        confirmed: spec.confirmed,
        pending: spec.pending,
      ),
    );
  }

  return _SeededWorld(
    db: db,
    service: InventoryQueryService(db),
    varietyIds: varietyIds,
    crossIds: crossIds,
    stock: seededStock,
  );
}

/// A seeded stock row with everything needed to recompute its expected
/// available (confirmed-only) CFT independently of the service.
class _SeededStock {
  const _SeededStock({
    required this.stockId,
    required this.varietyId,
    required this.crossSectionId,
    required this.crossDomain,
    required this.isReaper,
    required this.lengthFt,
    required this.confirmed,
    required this.pending,
  });

  final int stockId;
  final int varietyId;
  final int crossSectionId;
  final CrossSection crossDomain;
  final bool isReaper;
  final int lengthFt;
  final int confirmed;
  final int pending;

  /// The exact available CFT this item should contribute: confirmed-only, and
  /// zero when the confirmed balance is zero.
  Cft get availableCft => confirmed > 0
      ? _calc.lineCftFor(crossDomain, lengthFt, confirmed)
      : Cft.zero;
}

/// The seeded world under test: the open db, the service, and the lookup pools.
class _SeededWorld {
  const _SeededWorld({
    required this.db,
    required this.service,
    required this.varietyIds,
    required this.crossIds,
    required this.stock,
  });

  final AppDatabase db;
  final InventoryQueryService service;
  final List<int> varietyIds;
  final List<int> crossIds;
  final List<_SeededStock> stock;
}

/// Builds the concrete [InventoryFilter] for [spec] against the seeded pools,
/// resolving nullable indices to real seeded ids (null = no constraint). A
/// filter index that lands outside the seeded pool is clamped with modulo so it
/// still names a real row; this keeps the filter meaningful without ever
/// pointing at a non-existent id.
InventoryFilter _buildFilter(_FilterSpec spec, _SeededWorld world) {
  int? varietyId;
  if (spec.varietyIndex != null) {
    varietyId = world.varietyIds[spec.varietyIndex! % world.varietyIds.length];
  }
  int? crossSectionId;
  if (spec.crossIndex != null) {
    crossSectionId = world.crossIds[spec.crossIndex! % world.crossIds.length];
  }
  return InventoryFilter(
    varietyId: varietyId,
    crossSectionId: crossSectionId,
    category:
        spec.useCategory ? (spec.useReaperCategory
            ? CategoryKind.reaper
            : CategoryKind.plank) : null,
    lengthFt: spec.lengthFt,
    includeZeroStock: spec.includeZeroStock,
  );
}

/// Independently decides whether a seeded [stock] item passes [filter], exactly
/// mirroring the service's documented rules (AND of non-null dimensions; the
/// zero-stock toggle drops only zero-CONFIRMED items). This oracle is written
/// against the specification, not by calling the service.
bool _passes(_SeededStock stock, InventoryFilter filter) {
  if (filter.varietyId != null && stock.varietyId != filter.varietyId) {
    return false;
  }
  if (filter.crossSectionId != null &&
      stock.crossSectionId != filter.crossSectionId) {
    return false;
  }
  if (filter.category != null) {
    final kind = stock.isReaper ? CategoryKind.reaper : CategoryKind.plank;
    if (kind != filter.category) return false;
  }
  if (filter.lengthFt != null && stock.lengthFt != filter.lengthFt) {
    return false;
  }
  if (!filter.includeZeroStock && stock.confirmed == 0) return false;
  return true;
}

void main() {
  group('Inventory totals over the active filter (Property 23, glados)', () {
    Glados<_Scenario>(_scenarioGen, _explore).test(
      'Feature: wood-cft-app, Property 23: Inventory totals equal the sum over '
      'the active filter - the displayed total CFT (and piece count) equals the '
      'exact confirmed-only sum of exactly the items passing the filter, is '
      'order-independent, and never includes items the filter excludes '
      '(Requirements 6.1, 6.3)',
      (_Scenario scenario) async {
        final world = await _seed(scenario);
        try {
          final filter = _buildFilter(scenario.filter, world);
          final result = await world.service.query(filter);

          // Independent oracle: exactly the seeded items that pass the filter.
          final expectedPassing =
              world.stock.where((s) => _passes(s, filter)).toList();

          // --- (1) Sum-over-the-filter: exact CFT + integer pieces. ---
          var expectedCft = Rational.zero;
          var expectedPieces = 0;
          for (final s in expectedPassing) {
            expectedCft += s.availableCft.value;
            expectedPieces += s.confirmed;
          }
          expect(
            result.totalAvailableCft.value,
            expectedCft,
            reason: 'total CFT must equal the exact confirmed-only sum over '
                'exactly the passing items',
          );
          expect(
            result.totalAvailablePieces,
            expectedPieces,
            reason: 'total pieces must equal the confirmed sum over the '
                'passing items',
          );

          // The service's rows must be exactly the passing set (by id).
          expect(
            result.rows.map((r) => r.stockItemId).toSet(),
            expectedPassing.map((s) => s.stockId).toSet(),
            reason: 'rows must be exactly the items that pass the filter',
          );

          // --- (2) Order independence: re-sum the matching CFT shuffled. ---
          final matchingCft = [for (final s in expectedPassing) s.availableCft];
          final shuffled = [...matchingCft]
            ..shuffle(math.Random(expectedPassing.length * 31 + 7));
          expect(
            _calc.totalCft(shuffled).value,
            result.totalAvailableCft.value,
            reason: 'summation order must not change the filtered total',
          );

          // --- (3) Excluded items never contribute. ---
          // Re-adding every excluded item's confirmed-only CFT to the reported
          // total must reproduce the whole-inventory confirmed CFT. If any
          // excluded item had leaked into the total, this identity would break.
          final excluded =
              world.stock.where((s) => !_passes(s, filter)).toList();
          var wholeInventoryCft = Rational.zero;
          for (final s in world.stock) {
            wholeInventoryCft += s.availableCft.value;
          }
          var excludedCft = Rational.zero;
          for (final s in excluded) {
            excludedCft += s.availableCft.value;
          }
          expect(
            result.totalAvailableCft.value + excludedCft,
            wholeInventoryCft,
            reason: 'excluded items must not contribute to the filtered total',
          );
          // No excluded id may appear among the reported rows.
          final rowIds = result.rows.map((r) => r.stockItemId).toSet();
          for (final s in excluded) {
            expect(
              rowIds.contains(s.stockId),
              isFalse,
              reason: 'an excluded item must never appear in the rows',
            );
          }

          // --- (4) Zero-stock toggle consistency. ---
          // Hiding zero-stock must drop exactly the zero-CONFIRMED rows and
          // nothing else; since those rows always contribute zero CFT, the two
          // totals must be identical, and the hidden row set must equal the
          // shown set minus the zero-confirmed rows.
          final shown =
              await world.service.query(filter.copyWith(includeZeroStock: true));
          final hidden = await world.service
              .query(filter.copyWith(includeZeroStock: false));

          expect(
            hidden.totalAvailableCft.value,
            shown.totalAvailableCft.value,
            reason: 'toggling zero-stock drops only zero-CFT rows, so the '
                'filtered total CFT is unchanged',
          );
          expect(
            hidden.totalAvailablePieces,
            shown.totalAvailablePieces,
            reason: 'zero-confirmed rows carry zero pieces, so the piece total '
                'is unchanged by the toggle',
          );

          final shownIds = shown.rows.map((r) => r.stockItemId).toSet();
          final hiddenIds = hidden.rows.map((r) => r.stockItemId).toSet();
          final zeroConfirmedShownIds = shown.rows
              .where((r) => r.availablePieces == 0)
              .map((r) => r.stockItemId)
              .toSet();
          expect(
            hiddenIds,
            shownIds.difference(zeroConfirmedShownIds),
            reason: 'hiding zero-stock removes exactly the zero-confirmed rows',
          );
        } finally {
          await world.db.close();
        }
      },
    );
  });
}
