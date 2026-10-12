/// Riverpod wiring for the Stock-tab inventory browser (task 6.2).
///
/// This binds the headless [InventoryQueryService] (task 6.1) to the on-device
/// drift `AppDatabase` and exposes the live [InventoryFilter] the browser's
/// filter controls and zero-stock toggle drive, plus the resolved
/// [InventoryQueryResult] the browser renders (design.md -> Screen Flows ->
/// Stock tab; Requirements 6.1â€“6.5).
///
/// The database is NOT redeclared here: it reuses the single
/// [appDatabaseProvider] defined in `business_profile_providers.dart`, so the
/// whole app (settings, inventory, â€¦) shares one database and tests override
/// exactly one provider.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wood_cft/application/inventory_query_service.dart';
import 'package:wood_cft/application/receiving_service.dart';
import 'package:wood_cft/data/tables.dart' show CategoryKind;
import 'package:wood_cft/presentation/settings/business_profile_providers.dart'
    show appDatabaseProvider;

export 'package:wood_cft/presentation/settings/business_profile_providers.dart'
    show appDatabaseProvider;

/// Provides the inventory query engine bound to [appDatabaseProvider].
///
/// Reuses the shared `CalculationService` default inside
/// [InventoryQueryService] so every CFT value on the Stock tab comes from the
/// one engine (design.md -> Components and Interfaces).
final inventoryQueryServiceProvider = Provider<InventoryQueryService>((ref) {
  return InventoryQueryService(ref.watch(appDatabaseProvider));
});

/// The live inventory filter the browser's controls mutate.
///
/// Defaults to an all-`null` filter with `includeZeroStock: true` (show
/// everything). The variety / category / cross-section / length controls
/// (Requirement 6.1) and the show/hide zero-stock toggle (Requirement 6.4)
/// update this notifier; [inventoryQueryProvider] re-runs whenever it changes.
final inventoryFilterProvider =
    NotifierProvider<InventoryFilterNotifier, InventoryFilter>(
  InventoryFilterNotifier.new,
);

/// Holds and mutates the current [InventoryFilter] for the browser.
class InventoryFilterNotifier extends Notifier<InventoryFilter> {
  @override
  InventoryFilter build() => const InventoryFilter();

  /// Replaces the whole filter.
  void set(InventoryFilter filter) => state = filter;

  /// Sets (or clears, with `null`) the variety constraint (Requirement 6.1).
  void setVariety(int? varietyId) =>
      state = _copy(varietyId: varietyId, clearVariety: varietyId == null);

  /// Sets (or clears, with `null`) the category constraint (Requirement 6.1).
  void setCategory(CategoryKind? category) =>
      state = _copy(category: category, clearCategory: category == null);

  /// Sets (or clears) the cross-section constraint (Requirement 6.1).
  void setCrossSection(int? crossSectionId) => state = _copy(
        crossSectionId: crossSectionId,
        clearCrossSection: crossSectionId == null,
      );

  /// Sets (or clears) the length constraint (Requirement 6.1).
  void setLength(int? lengthFt) =>
      state = _copy(lengthFt: lengthFt, clearLength: lengthFt == null);

  /// Toggles whether zero-(confirmed-)stock items are shown (Requirement 6.4).
  void setIncludeZeroStock(bool include) =>
      state = state.copyWith(includeZeroStock: include);

  /// Clears every filter field back to the default (all-null, show zero stock).
  void clearAll() => state = const InventoryFilter();

  // `InventoryFilter.copyWith` can't clear a field back to null (it keeps the
  // old value on a null argument), so rebuild explicitly when clearing.
  InventoryFilter _copy({
    int? varietyId,
    CategoryKind? category,
    int? crossSectionId,
    int? lengthFt,
    bool clearVariety = false,
    bool clearCategory = false,
    bool clearCrossSection = false,
    bool clearLength = false,
  }) =>
      InventoryFilter(
        varietyId: clearVariety ? null : (varietyId ?? state.varietyId),
        category: clearCategory ? null : (category ?? state.category),
        crossSectionId:
            clearCrossSection ? null : (crossSectionId ?? state.crossSectionId),
        lengthFt: clearLength ? null : (lengthFt ?? state.lengthFt),
        includeZeroStock: state.includeZeroStock,
      );
}

/// Runs the current [inventoryFilterProvider] against the query service and
/// exposes the result the browser renders.
final inventoryQueryProvider =
    FutureProvider.autoDispose<InventoryQueryResult>((ref) async {
  // Local-only app: there is no pending state. Promote any still-pending stock
  // (e.g. received before this behavior existed) to confirmed so it shows as
  // available immediately. Idempotent and cheap.
  await ReceivingService(ref.watch(appDatabaseProvider)).confirmAllPending();
  final service = ref.watch(inventoryQueryServiceProvider);
  final filter = ref.watch(inventoryFilterProvider);
  return service.query(filter);
});

/// The unfiltered inventory (every item, including zero stock) used only to
/// populate the browser's filter controls with the varieties, cross-sections,
/// and lengths that actually exist, so the owner can only filter by real
/// values (Requirement 6.1).
final inventoryFilterOptionsProvider =
    FutureProvider.autoDispose<InventoryQueryResult>((ref) {
  final service = ref.watch(inventoryQueryServiceProvider);
  return service.query(const InventoryFilter());
});
