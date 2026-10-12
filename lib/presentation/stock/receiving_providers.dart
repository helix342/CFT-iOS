/// Riverpod wiring for the Stock-tab receiving session UI (task 5.2).
///
/// This binds [ReceivingService] to the shared [appDatabaseProvider] (declared
/// in `business_profile_providers.dart` and reused here — never re-declared, so
/// a test override of the database reaches every surface at once) and exposes
/// the catalog reads the receiving grid needs: the active varieties, the active
/// cross-sections, and a lookup from (variety, cross-section, length) to the
/// persisted `StockItemRow`.
///
/// The receiving screen (task 5.2) selects a variety + cross-section and then
/// drives the compact 2–9 ft length grid through [ReceivingService]. Session
/// resume (5.3) and adjustment/undo (5.4) are separate tasks and are
/// intentionally NOT wired here.
///
/// Architecture rule (design.md): providers live in the presentation layer and
/// compose the application/data layers; the data-layer [CategoryKind] is mapped
/// to the domain [WoodCategory] here so the screen and [CalculationService]
/// speak the domain vocabulary.
library;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/application/receiving_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/presentation/settings/business_profile_providers.dart';

/// The shared, stateless CFT engine used for the piece-equivalent and CFT
/// read-outs on the receiving grid.
final calculationServiceProvider = Provider<CalculationService>(
  (ref) => const CalculationService(),
);

/// Provides [ReceivingService] bound to the shared [appDatabaseProvider].
///
/// Reuses `appDatabaseProvider` from `business_profile_providers.dart` so tests
/// override a single database provider for the whole app.
final receivingServiceProvider = Provider<ReceivingService>((ref) {
  return ReceivingService(
    ref.watch(appDatabaseProvider),
    calculationService: ref.watch(calculationServiceProvider),
  );
});

/// The active wood varieties available for new receiving (Requirement 1.5).
final receivingVarietiesProvider = FutureProvider<List<WoodVarietyRow>>((
  ref,
) async {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.woodVarieties)
        ..where((v) => v.active.equals(true))
        ..orderBy([(v) => OrderingTerm.asc(v.name)]))
      .get();
});

/// The active cross-sections available for new receiving (Requirement 1.5),
/// each mapped to the domain [CrossSection] the grid and engine consume.
final receivingCrossSectionsProvider = FutureProvider<List<CrossSection>>((
  ref,
) async {
  final db = ref.watch(appDatabaseProvider);
  final rows = await (db.select(db.crossSections)
        ..where((c) => c.active.equals(true))
        ..orderBy([(c) => OrderingTerm.asc(c.id)]))
      .get();
  return rows.map(toDomainCrossSection).toList(growable: false);
});

/// Reads the `StockItemRow` for the given `varietyId` + `crossSectionId` + `lengthFt` business key, or null when no row exists yet.
///
/// Receiving targets an existing stock item (the catalog is seeded with a row
/// per variety × cross-section × length — task 2.2 / 3.1), so the grid resolves
/// the stock-item id to commit against through this lookup.
final stockItemLookupProvider =
    FutureProvider.family<StockItemRow?, StockItemKey>((ref, key) async {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.stockItems)
        ..where(
          (s) =>
              s.varietyId.equals(key.varietyId) &
              s.crossSectionId.equals(key.crossSectionId) &
              s.lengthFt.equals(key.lengthFt),
        )
        ..limit(1))
      .getSingleOrNull();
});

/// The business key used to look up a persisted stock item for the grid.
@immutable
class StockItemKey {
  /// Creates a lookup key.
  const StockItemKey({
    required this.varietyId,
    required this.crossSectionId,
    required this.lengthFt,
  });

  /// Owning variety id.
  final int varietyId;

  /// Owning cross-section id.
  final int crossSectionId;

  /// Piece length in feet (2–9).
  final int lengthFt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockItemKey &&
          varietyId == other.varietyId &&
          crossSectionId == other.crossSectionId &&
          lengthFt == other.lengthFt);

  @override
  int get hashCode => Object.hash(varietyId, crossSectionId, lengthFt);
}

/// Maps a persisted [CrossSectionRow] to the domain [CrossSection].
///
/// The data-layer [CategoryKind] and the domain [WoodCategory] are independent
/// enums (design.md); the bunch size is carried across explicitly.
CrossSection toDomainCrossSection(CrossSectionRow row) => CrossSection(
  id: row.id,
  widthIn: row.widthIn,
  thicknessIn: row.thicknessIn,
  category: _toDomainCategory(row.category),
  bunchSize: row.bunchSize,
  active: row.active,
);

WoodCategory _toDomainCategory(CategoryKind kind) => switch (kind) {
  CategoryKind.reaper => WoodCategory.reaper,
  CategoryKind.plank => WoodCategory.plank,
};
