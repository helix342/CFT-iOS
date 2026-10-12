/// Riverpod wiring for the Sell-tab allocation review / picking-list surface
/// (task 9.5).
///
/// This composes the two pieces the picking list needs and nothing else:
///
///   * the structured requests the owner staged on the draft, read from the
///     shared `draftOrderRequestsProvider` in `sell_providers.dart` (NOT
///     redeclared here); and
///   * the CONFIRMED, sellable availability of every stock item, read from the
///     shared [appDatabaseProvider] (also reused, never redeclared), mapped to
///     the headless `AllocationService.SkuAvailability` snapshot the engine
///     consumes.
///
/// It then runs the single shared `AllocationService.allocateOrder` over the
/// staged requests against that confirmed snapshot and exposes the resulting
/// [OrderAllocation] for the review screen (task 9.5). Running the heuristic is
/// the application layer's job — this provider only wires the draft + the
/// confirmed inventory into it and surfaces the result.
///
/// Availability rule (design.md -> "Local cache vs hosted schema";
/// Requirement 19.8): only the `confirmed_balance_pieces` is sellable, so the
/// snapshot is built from the confirmed balance ONLY. Pending receiving stock
/// is never offered to the allocator, so a line can never be "fulfilled" from
/// stock that has not yet been confirmed. The flattened snapshot names each
/// stock item exactly once, which is exactly what `allocateOrder` requires to
/// keep the per-item remaining balance unambiguous (no double-count across
/// lines — Property 10).
///
/// SCOPE (task 9.5): review / picking-list display only. The underlying
/// multi-line allocation (tasks 9.1–9.4) already exists; this provider does not
/// mutate stock, does not finalise, and does not persist anything — it is a
/// read-only composition of the draft and the confirmed inventory.
///
/// Architecture rule (design.md): providers live in the presentation layer and
/// compose the application/data layers; the data-layer `CrossSectionRow` is
/// mapped to the domain `CrossSection` (via `toDomainCrossSection`) so the
/// engine speaks the domain vocabulary.
library;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wood_cft/application/allocation_service.dart';
import 'package:wood_cft/presentation/sell/sell_providers.dart';
import 'package:wood_cft/presentation/stock/receiving_providers.dart'
    show toDomainCrossSection;

export 'package:wood_cft/presentation/sell/sell_providers.dart'
    show appDatabaseProvider, draftOrderRequestsProvider;

/// The shared stateless [AllocationService] (uses the default shared
/// `CalculationService`), so every CFT on the picking list matches the stock
/// views, billing, and exports exactly (design.md -> Components and
/// Interfaces).
final allocationServiceProvider = Provider<AllocationService>((ref) {
  return const AllocationService();
});

/// The CONFIRMED (sellable) availability snapshot for every stock item, built
/// from the shared [appDatabaseProvider] and mapped to the engine's
/// [SkuAvailability] (Requirement 19.8).
///
/// Each stock item appears at most once (its primary key is unique), so the
/// list satisfies `AllocationService.allocateOrder`'s one-entry-per-stock-item
/// precondition. The CFT dimensions and bunch size travel on each entry's
/// domain `CrossSection`.
final confirmedAvailabilityProvider =
    FutureProvider<List<SkuAvailability>>((ref) async {
  final db = ref.watch(appDatabaseProvider);

  final joined = await (db.select(db.stockItems).join([
    innerJoin(
      db.crossSections,
      db.crossSections.id.equalsExp(db.stockItems.crossSectionId),
    ),
  ])..orderBy([OrderingTerm.asc(db.stockItems.id)]))
      .get();

  return [
    for (final r in joined)
      () {
        final stock = r.readTable(db.stockItems);
        final crossSection = toDomainCrossSection(r.readTable(db.crossSections));
        return SkuAvailability(
          stockItemId: stock.id,
          crossSection: crossSection,
          lengthFt: stock.lengthFt,
          // CONFIRMED balance only — pending stock is never sellable (Req 19.8).
          availablePieces: stock.confirmedBalancePieces,
        );
      }(),
  ];
});

/// Runs the shared [AllocationService] over the staged draft requests against
/// the [confirmedAvailabilityProvider] snapshot and exposes the resulting
/// [OrderAllocation] for the picking-list review (task 9.5).
///
/// Returns `null` when the draft is empty (nothing to review yet). Any staged
/// shape the multi-line allocator does not support (currently the
/// category-flexible request — task 9.x beyond 9.4) surfaces as the provider's
/// error state so the review screen can tell the owner rather than silently
/// mis-allocating.
final orderAllocationProvider = FutureProvider<OrderAllocation?>((ref) async {
  final requests = ref.watch(draftOrderRequestsProvider);
  if (requests.isEmpty) {
    return null;
  }
  final availability = await ref.watch(confirmedAvailabilityProvider.future);
  final service = ref.watch(allocationServiceProvider);
  return service.allocateOrder(requests, availability);
});
