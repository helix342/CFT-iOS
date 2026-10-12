/// The headless inventory query + filter engine for the Stock-tab browser
/// (task 6.1).
///
/// [InventoryQueryService] answers the question the inventory browser asks:
/// "given a filter, which stock items match, how much of each is available,
/// and what is the available CFT and total?" It reads the local cache
/// (`StockItems` joined to their `WoodVarieties` and `CrossSections`) and
/// routes every volume through the single shared `CalculationService` so the
/// browser, previews, and invoices can never disagree about a CFT value
/// (design.md -> Screen Flows -> Stock tab; Components and Interfaces).
///
/// Availability rule (design.md -> "Local cache vs hosted schema";
/// Requirements 6.2, 19.8, 5.6a): the **available / sellable** quantity is the
/// `confirmed_balance_pieces` only. The `pending_balance_pieces`
/// (`Pending_Receiving_Stock`) is reported per item so the browser UI (task
/// 6.2) can badge it separately, but it is **never** counted toward available
/// quantity or available CFT, and never toward the filtered totals.
///
/// Totals rule (Requirements 6.1, 6.3; Correctness Property 23): the total
/// available CFT across a filter is the exact unrounded sum — via
/// `CalculationService.totalCft` — of the available CFT of exactly the items
/// that pass the filter, and the total pieces is the integer sum of their
/// available (confirmed) pieces.
///
/// This is strictly headless/testable application logic. It builds NO
/// Cupertino UI (the browser widget, badges, zero-stock toggle, and unit
/// labels are task 6.2); it only reads the cache and computes rows + totals.
///
/// Architecture rule (design.md): this service depends on `domain` and `data`
/// and MUST NOT import `package:flutter/*`, so it runs under `flutter test` on
/// Windows without a device.
library;

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/cft.dart';

/// A filter over the inventory. Any combination of fields may be set; a `null`
/// field imposes no constraint on that dimension (Requirement 6.1).
///
/// All constraints are combined with logical AND: an item passes only when it
/// satisfies every non-null field.
@immutable
class InventoryFilter {
  /// Creates an inventory filter. Every field is optional; an all-`null`
  /// filter matches every stock item.
  const InventoryFilter({
    this.varietyId,
    this.category,
    this.crossSectionId,
    this.lengthFt,
    this.includeZeroStock = true,
  });

  /// When set, only items of this variety pass (Requirement 6.1).
  final int? varietyId;

  /// When set, only items whose cross-section has this category pass
  /// (Requirement 6.1).
  final CategoryKind? category;

  /// When set, only items of this cross-section pass (Requirement 6.1).
  final int? crossSectionId;

  /// When set, only items of this length (feet) pass (Requirement 6.1).
  final int? lengthFt;

  /// Whether items whose available (confirmed) quantity is zero are included.
  ///
  /// Defaults to `true` (show everything). The browser UI's show/hide
  /// zero-stock toggle (task 6.2, Requirement 6.4) sets this. Hiding
  /// zero-stock drops an item only when its CONFIRMED balance is zero; an item
  /// with pending-only stock still counts as zero available and is hidden when
  /// this is `false`.
  final bool includeZeroStock;

  /// Returns a copy of this filter with the given fields replaced.
  InventoryFilter copyWith({
    int? varietyId,
    CategoryKind? category,
    int? crossSectionId,
    int? lengthFt,
    bool? includeZeroStock,
  }) => InventoryFilter(
    varietyId: varietyId ?? this.varietyId,
    category: category ?? this.category,
    crossSectionId: crossSectionId ?? this.crossSectionId,
    lengthFt: lengthFt ?? this.lengthFt,
    includeZeroStock: includeZeroStock ?? this.includeZeroStock,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InventoryFilter &&
          varietyId == other.varietyId &&
          category == other.category &&
          crossSectionId == other.crossSectionId &&
          lengthFt == other.lengthFt &&
          includeZeroStock == other.includeZeroStock);

  @override
  int get hashCode => Object.hash(
    varietyId,
    category,
    crossSectionId,
    lengthFt,
    includeZeroStock,
  );

  @override
  String toString() =>
      'InventoryFilter(varietyId: $varietyId, category: $category, '
      'crossSectionId: $crossSectionId, lengthFt: $lengthFt, '
      'includeZeroStock: $includeZeroStock)';
}

/// A single stock item as presented in the inventory browser: identity,
/// dimensions, the available (sellable) quantity and CFT, and the display-only
/// pending quantity.
///
/// The available figures are CONFIRMED-only; [pendingPieces] is carried
/// alongside purely so the UI can badge `Pending_Receiving_Stock` separately
/// (Requirements 6.2, 19.8). Pending stock is never included in
/// [availablePieces] or [availableCft].
@immutable
class InventoryRow {
  /// Creates an inventory row.
  const InventoryRow({
    required this.stockItemId,
    required this.varietyId,
    required this.varietyName,
    required this.crossSectionId,
    required this.crossSectionLabel,
    required this.category,
    required this.lengthFt,
    required this.availablePieces,
    required this.pendingPieces,
    required this.availableCft,
  });

  /// The stock item's identity.
  final int stockItemId;

  /// The owning variety's identity.
  final int varietyId;

  /// The owning variety's display name (as stored).
  final String varietyName;

  /// The owning cross-section's identity.
  final int crossSectionId;

  /// The cross-section inch label, e.g. `"2 × 1 in"` (Requirement 1.8).
  final String crossSectionLabel;

  /// The cross-section's category (reaper or plank).
  final CategoryKind category;

  /// The piece length in feet.
  final int lengthFt;

  /// Available (sellable) quantity in whole pieces — the CONFIRMED balance
  /// only (Requirement 6.2). Never includes pending stock.
  final int availablePieces;

  /// Display-only pending quantity in pieces (`Pending_Receiving_Stock`).
  ///
  /// Carried so the browser can badge it separately; NOT part of the available
  /// quantity or CFT and NOT part of any total (Requirements 6.2, 19.8).
  final int pendingPieces;

  /// The exact available CFT for this item: `cftPerPiece × availablePieces`
  /// via `CalculationService`. [Cft.zero] when [availablePieces] is zero.
  final Cft availableCft;

  @override
  String toString() =>
      'InventoryRow(stockItemId: $stockItemId, variety: $varietyName, '
      'label: $crossSectionLabel, lengthFt: $lengthFt, '
      'available: $availablePieces, pending: $pendingPieces, '
      'availableCft: ${availableCft.toFixed()})';
}

/// The result of an inventory query: the matching [rows] plus the exact totals
/// across the active filter (Requirements 6.1, 6.3; Property 23).
@immutable
class InventoryQueryResult {
  /// Creates an inventory query result.
  const InventoryQueryResult({
    required this.rows,
    required this.totalAvailablePieces,
    required this.totalAvailableCft,
    required this.totalPendingPieces,
  });

  /// The stock items that passed the filter, each with its available figures.
  final List<InventoryRow> rows;

  /// The integer sum of available (confirmed) pieces over [rows]
  /// (Requirement 6.3).
  final int totalAvailablePieces;

  /// The exact unrounded sum of available CFT over [rows], computed with
  /// `CalculationService.totalCft` (Requirement 6.3; Property 23).
  final Cft totalAvailableCft;

  /// The integer sum of pending pieces over [rows]. Display-only; reported so
  /// the browser can summarise pending stock, but excluded from the available
  /// totals (Requirements 6.2, 19.8).
  final int totalPendingPieces;

  @override
  String toString() =>
      'InventoryQueryResult(rows: ${rows.length}, '
      'totalAvailablePieces: $totalAvailablePieces, '
      'totalAvailableCft: ${totalAvailableCft.toFixed()}, '
      'totalPendingPieces: $totalPendingPieces)';
}

/// Reads the local cache and computes filtered inventory rows + exact totals
/// for the Stock-tab browser. Headless; no Cupertino UI (task 6.2).
class InventoryQueryService {
  /// Creates the query service over [_db], using the shared
  /// `CalculationService` (defaults to a `const CalculationService()`) for
  /// every CFT value.
  InventoryQueryService(
    this._db, [
    this._calc = const CalculationService(),
  ]);

  final AppDatabase _db;

  final CalculationService _calc;

  /// Runs [filter] against the inventory and returns the matching rows and the
  /// exact totals across those rows.
  ///
  /// Behaviour:
  ///   * filters by any combination of variety, category, cross-section, and
  ///     length (Requirement 6.1); a null filter field imposes no constraint;
  ///   * computes each row's available quantity from the CONFIRMED balance and
  ///     its available CFT via `CalculationService` (Requirement 6.2);
  ///   * reports each row's pending quantity for display only, never counting
  ///     it as available (Requirements 6.2, 19.8);
  ///   * drops items with zero available (confirmed) pieces when
  ///     `filter.includeZeroStock` is false (Requirement 6.4);
  ///   * returns the exact total available CFT (via
  ///     `CalculationService.totalCft`) and the integer total available pieces
  ///     over exactly the passing rows (Requirement 6.3; Property 23).
  ///
  /// Rows are ordered deterministically by stock-item id so the browser and
  /// tests see a stable sequence.
  Future<InventoryQueryResult> query(InventoryFilter filter) async {
    // Pull the joined catalog so we can filter by category (which lives on the
    // cross-section) and build inch labels + exact CFT per item. The variety
    // and cross-section filters are pushed into SQL; category is applied in
    // Dart against the joined cross-section row (it maps cleanly either way,
    // and keeps the category source of truth on the cross-section).
    final query = _db.select(_db.stockItems).join([
      innerJoin(
        _db.woodVarieties,
        _db.woodVarieties.id.equalsExp(_db.stockItems.varietyId),
      ),
      innerJoin(
        _db.crossSections,
        _db.crossSections.id.equalsExp(_db.stockItems.crossSectionId),
      ),
    ]);

    if (filter.varietyId != null) {
      query.where(_db.stockItems.varietyId.equals(filter.varietyId!));
    }
    if (filter.crossSectionId != null) {
      query.where(
        _db.stockItems.crossSectionId.equals(filter.crossSectionId!),
      );
    }
    if (filter.lengthFt != null) {
      query.where(_db.stockItems.lengthFt.equals(filter.lengthFt!));
    }
    if (filter.category != null) {
      query.where(_db.crossSections.category.equalsValue(filter.category!));
    }

    query.orderBy([OrderingTerm.asc(_db.stockItems.id)]);

    final joined = await query.get();

    final rows = <InventoryRow>[];
    final availableCfts = <Cft>[];
    var totalAvailablePieces = 0;
    var totalPendingPieces = 0;

    for (final r in joined) {
      final stock = r.readTable(_db.stockItems);
      final variety = r.readTable(_db.woodVarieties);
      final crossSectionRow = r.readTable(_db.crossSections);

      final availablePieces = stock.confirmedBalancePieces;

      // Zero-stock toggle: an item is "zero stock" when its CONFIRMED
      // (available) balance is zero, regardless of any pending receiving stock.
      if (!filter.includeZeroStock && availablePieces == 0) {
        continue;
      }

      final crossSection = _toDomainCrossSection(crossSectionRow);

      // Available CFT is confirmed-only. Zero pieces -> zero CFT (and
      // `lineCft` requires a positive quantity, so guard the empty case).
      final availableCft = availablePieces > 0
          ? _calc.lineCftFor(crossSection, stock.lengthFt, availablePieces)
          : Cft.zero;

      rows.add(
        InventoryRow(
          stockItemId: stock.id,
          varietyId: variety.id,
          varietyName: variety.name,
          crossSectionId: crossSection.id,
          crossSectionLabel: crossSection.inchLabel,
          category: crossSectionRow.category,
          lengthFt: stock.lengthFt,
          availablePieces: availablePieces,
          pendingPieces: stock.pendingBalancePieces,
          availableCft: availableCft,
        ),
      );

      availableCfts.add(availableCft);
      totalAvailablePieces += availablePieces;
      totalPendingPieces += stock.pendingBalancePieces;
    }

    // Exact, order-independent total via the single shared engine so the
    // filtered total equals the exact sum over the passing items (Property 23).
    final totalAvailableCft = _calc.totalCft(availableCfts);

    return InventoryQueryResult(
      rows: rows,
      totalAvailablePieces: totalAvailablePieces,
      totalAvailableCft: totalAvailableCft,
      totalPendingPieces: totalPendingPieces,
    );
  }

  /// Maps a persisted [CrossSectionRow] to the domain [CrossSection] that
  /// `CalculationService` consumes. The data-layer [CategoryKind] and the
  /// domain [WoodCategory] are kept as independent enums (design.md), so the
  /// bunch size is carried across explicitly rather than re-derived.
  CrossSection _toDomainCrossSection(CrossSectionRow row) => CrossSection(
    id: row.id,
    widthIn: row.widthIn,
    thicknessIn: row.thicknessIn,
    category: _toDomainCategory(row.category),
    bunchSize: row.bunchSize,
    active: row.active,
  );

  /// Maps the data-layer [CategoryKind] to the domain [WoodCategory].
  WoodCategory _toDomainCategory(CategoryKind kind) => switch (kind) {
    CategoryKind.reaper => WoodCategory.reaper,
    CategoryKind.plank => WoodCategory.plank,
  };
}
