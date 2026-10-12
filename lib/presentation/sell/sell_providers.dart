/// Riverpod wiring for the Sell-tab order-entry UI (task 8.2).
///
/// This exposes the catalog reads the order-entry forms need — the active
/// varieties and the active cross-sections (mapped to the domain [CrossSection]
/// the forms and engine consume) — plus a draft-request store that collects the
/// structured [OrderRequest]s the owner builds before allocation
/// (design.md -> Screen Flows -> Sell tab).
///
/// The database is NOT redeclared here: it reuses the single
/// [appDatabaseProvider] defined in `business_profile_providers.dart` (the same
/// provider the Stock tab overrides in tests), so the whole app shares one
/// database and a test override reaches every surface at once.
///
/// SCOPE (task 8.2): order-request ENTRY only. The forms produce validated
/// [OrderRequest] value objects (one of the four structured shapes —
/// Requirements 7.2–7.5) and stage them on the draft. Running the allocation
/// heuristic and the allocation-review / picking-list surface are later tasks
/// (8.1 service already exists; the review UI is task 9.5), so no
/// `AllocationService` is wired here.
///
/// Architecture rule (design.md): providers live in the presentation layer and
/// compose the application/data layers; the data-layer `CategoryKind` is mapped
/// to the domain `WoodCategory` (via `toDomainCrossSection`) so the screen and
/// `CalculationService` speak the domain vocabulary.
library;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/order_request.dart';
import 'package:wood_cft/presentation/settings/business_profile_providers.dart';
import 'package:wood_cft/presentation/stock/receiving_providers.dart'
    show toDomainCrossSection;

export 'package:wood_cft/presentation/settings/business_profile_providers.dart'
    show appDatabaseProvider;

/// The active wood varieties available for new selling (Requirement 1.5).
///
/// A deactivated variety is never offered for a new order, mirroring the
/// receiving surface's active-only rule.
final sellVarietiesProvider = FutureProvider<List<WoodVarietyRow>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.woodVarieties)
        ..where((v) => v.active.equals(true))
        ..orderBy([(v) => OrderingTerm.asc(v.name)]))
      .get();
});

/// The active cross-sections available for new selling (Requirement 1.5), each
/// mapped to the domain [CrossSection] the forms and engine consume.
final sellCrossSectionsProvider = FutureProvider<List<CrossSection>>((
  ref,
) async {
  final db = ref.watch(appDatabaseProvider);
  final rows = await (db.select(db.crossSections)
        ..where((c) => c.active.equals(true))
        ..orderBy([(c) => OrderingTerm.asc(c.id)]))
      .get();
  return rows.map(toDomainCrossSection).toList(growable: false);
});

/// Holds the structured [OrderRequest]s the owner has staged for the current
/// draft order (design.md -> Data Models -> DraftOrderRequest).
///
/// The order-entry forms append a validated request through
/// [DraftOrderRequestsNotifier.add]; the Sell screen renders the staged list
/// and can [DraftOrderRequestsNotifier.removeAt] or
/// [DraftOrderRequestsNotifier.clear] it. The list is
/// immutable per emission so Riverpod rebuilds observers on every change.
final draftOrderRequestsProvider =
    NotifierProvider<DraftOrderRequestsNotifier, List<OrderRequest>>(
  DraftOrderRequestsNotifier.new,
);

/// Collects the staged order requests for the draft being built.
class DraftOrderRequestsNotifier extends Notifier<List<OrderRequest>> {
  @override
  List<OrderRequest> build() => const [];

  /// Appends a validated [request] to the draft.
  ///
  /// The [OrderRequest] subtypes validate their own shape in their
  /// constructors, so an impossible request can never reach this list.
  void add(OrderRequest request) =>
      state = [...state, request];

  /// Removes the staged request at [index] (no-op when out of range).
  void removeAt(int index) {
    if (index < 0 || index >= state.length) return;
    final next = [...state]..removeAt(index);
    state = next;
  }

  /// Clears every staged request back to an empty draft.
  void clear() => state = const [];
}
