/// Riverpod wiring for the Settings -> "Price matrix" screen (task 7.2).
///
/// This binds the headless [PricingService] (task 7.1) to the on-device drift
/// database and exposes the data the editable price-matrix grid renders:
/// the active varieties (rows), the active cross-sections (columns), and the
/// current rate — or MISSING marker — for every cell (design.md -> Screen
/// Flows, Settings: "price matrix (editable grid with visible missing-rate
/// markers)").
///
/// The database is reached through [appDatabaseProvider] (declared in
/// `business_profile_providers.dart`); this file deliberately does NOT redeclare
/// it, so a single [AppDatabase] instance (overridable in tests) backs every
/// settings surface.
library;

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/pricing_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/price_rate_repository.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/presentation/settings/business_profile_providers.dart';

/// Provides the price-matrix repository bound to [appDatabaseProvider].
final priceRateRepositoryProvider = Provider<PriceRateRepository>((ref) {
  return PriceRateRepository(ref.watch(appDatabaseProvider));
});

/// Provides the headless [PricingService] bound to [appDatabaseProvider].
///
/// This is the single application-layer entry point the grid uses to set,
/// clear, and look up rates (Req 4.1). The service holds no length-bearing API,
/// so the UI physically cannot vary a rate by length (Req 4.2).
final pricingServiceProvider = Provider<PricingService>((ref) {
  return PricingService(ref.watch(priceRateRepositoryProvider));
});

/// One row/column header plus its rate for a single matrix cell.
///
/// A cell is keyed by [varietyId] × [crossSectionId] only — length is never
/// part of the key (Req 4.2). [rate] is `null` when the rate is MISSING, which
/// the grid renders with a visible marker (Req 4.5).
@immutable
class PriceMatrixCell {
  /// Creates a cell for [varietyId] × [crossSectionId] holding [rate].
  const PriceMatrixCell({
    required this.varietyId,
    required this.crossSectionId,
    required this.rate,
  });

  /// The owning variety id.
  final int varietyId;

  /// The owning cross-section id.
  final int crossSectionId;

  /// The exact ₹/CFT rate, or `null` when the rate is missing (Req 4.5).
  final Rational? rate;

  /// Whether this cell has no valid rate and must show the missing marker.
  bool get isMissing => rate == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PriceMatrixCell &&
          varietyId == other.varietyId &&
          crossSectionId == other.crossSectionId &&
          rate == other.rate);

  @override
  int get hashCode => Object.hash(varietyId, crossSectionId, rate);
}

/// The full, rendered price matrix: varieties (rows) × cross-sections (columns)
/// with every cell's current rate or MISSING state.
@immutable
class PriceMatrix {
  /// Creates a price matrix snapshot.
  ///
  /// [cells] is indexed `[varietyId][crossSectionId]`; a pair with no entry is
  /// treated as a MISSING (empty-rate) cell by [cell].
  const PriceMatrix({
    required this.varieties,
    required this.crossSections,
    required this.cells,
  });

  /// Active varieties, in catalog order — the grid's rows.
  final List<WoodVariety> varieties;

  /// Active cross-sections, in catalog order — the grid's columns.
  final List<CrossSection> crossSections;

  /// Rate cells indexed `[varietyId][crossSectionId]`.
  final Map<int, Map<int, PriceMatrixCell>> cells;

  /// Returns the cell for [varietyId] × [crossSectionId].
  ///
  /// A pair with no stored row is reported as MISSING (an empty-rate cell), so
  /// every variety × cross-section intersection always has a cell to render
  /// (Req 4.3, 4.5).
  PriceMatrixCell cell(int varietyId, int crossSectionId) {
    return cells[varietyId]?[crossSectionId] ??
        PriceMatrixCell(
          varietyId: varietyId,
          crossSectionId: crossSectionId,
          rate: null,
        );
  }

  /// The number of cells with no rate — the count of missing markers shown.
  int get missingCount {
    var count = 0;
    for (final variety in varieties) {
      for (final crossSection in crossSections) {
        if (cell(variety.id, crossSection.id).isMissing) count++;
      }
    }
    return count;
  }
}

/// Loads and mutates the price matrix for the Settings grid.
///
/// [build] reads the active catalog (varieties × cross-sections) and the stored
/// rate cells and projects them into a [PriceMatrix]. [setRate] and [clearRate]
/// persist through [PricingService] and refresh the snapshot so the grid shows
/// the committed value (or missing marker) on the next frame.
class PriceMatrixNotifier extends AsyncNotifier<PriceMatrix> {
  @override
  Future<PriceMatrix> build() => _load();

  Future<PriceMatrix> _load() async {
    final db = ref.watch(appDatabaseProvider);
    final repository = ref.watch(priceRateRepositoryProvider);

    final varieties = await _activeVarieties(db);
    final crossSections = await _activeCrossSections(db);
    final storedCells = await repository.allCells();

    final cells = <int, Map<int, PriceMatrixCell>>{};
    for (final c in storedCells) {
      (cells[c.varietyId] ??= <int, PriceMatrixCell>{})[c.crossSectionId] =
          PriceMatrixCell(
            varietyId: c.varietyId,
            crossSectionId: c.crossSectionId,
            rate: c.rate,
          );
    }

    return PriceMatrix(
      varieties: varieties,
      crossSections: crossSections,
      cells: cells,
    );
  }

  /// Sets the exact ₹/CFT [rate] for [varietyId] × [crossSectionId] (Req 4.1)
  /// and refreshes the matrix.
  Future<void> setRate({
    required int varietyId,
    required int crossSectionId,
    required Rational rate,
  }) async {
    final service = ref.read(pricingServiceProvider);
    state = const AsyncLoading<PriceMatrix>();
    state = await AsyncValue.guard(() async {
      await service.setRate(
        varietyId: varietyId,
        crossSectionId: crossSectionId,
        rate: rate,
      );
      return _load();
    });
  }

  /// Clears the rate for [varietyId] × [crossSectionId], marking it MISSING
  /// again (Req 4.5), and refreshes the matrix.
  Future<void> clearRate({
    required int varietyId,
    required int crossSectionId,
  }) async {
    final service = ref.read(pricingServiceProvider);
    state = const AsyncLoading<PriceMatrix>();
    state = await AsyncValue.guard(() async {
      await service.clearRate(
        varietyId: varietyId,
        crossSectionId: crossSectionId,
      );
      return _load();
    });
  }

  Future<List<WoodVariety>> _activeVarieties(AppDatabase db) async {
    final rows = await (db.select(db.woodVarieties)
          ..where((v) => v.active.equals(true))
          ..orderBy([(v) => OrderingTerm(expression: v.id)]))
        .get();
    return rows
        .map((r) => WoodVariety(id: r.id, name: r.name, active: r.active))
        .toList(growable: false);
  }

  Future<List<CrossSection>> _activeCrossSections(AppDatabase db) async {
    final rows = await (db.select(db.crossSections)
          ..where((c) => c.active.equals(true))
          ..orderBy([(c) => OrderingTerm(expression: c.id)]))
        .get();
    return rows
        .map(
          (r) => CrossSection(
            id: r.id,
            widthIn: r.widthIn,
            thicknessIn: r.thicknessIn,
            category: r.category == CategoryKind.reaper
                ? WoodCategory.reaper
                : WoodCategory.plank,
            bunchSize: r.bunchSize,
            active: r.active,
          ),
        )
        .toList(growable: false);
  }
}

/// The price-matrix notifier provider used by the price-matrix screen.
final priceMatrixProvider =
    AsyncNotifierProvider<PriceMatrixNotifier, PriceMatrix>(
  PriceMatrixNotifier.new,
);
