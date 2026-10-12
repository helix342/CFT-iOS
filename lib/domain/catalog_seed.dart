/// Pure-Dart catalog seed for the Wood CFT application (task 2.2).
///
/// This file defines the initial catalog the app ships with, as in-memory
/// domain objects from `catalog.dart`. It implements design.md -> Screen Flows
/// -> First-run setup: seed the varieties Mahogany/Kalani/Palajathi and the
/// cross-sections 2×1 Reaper plus 3×1…7×1 Plank, with all stock at zero and no
/// prices (Requirements 1.1, 1.2, 1.12).
///
/// Scope boundary (deliberate): this layer is pure data. It does NOT create any
/// persisted balances, movement-ledger rows, or `PriceRate` rows — those are
/// task 3 (persistence/ledger) and task 7 (price matrix) concerns. "All stock
/// starts at zero" and "no prices are seeded" are therefore represented as the
/// ABSENCE of any seeded balances and price rows: the seed never fabricates a
/// stock quantity and never fabricates a rate (Requirement 1.12). The helper
/// [kSeedStockItemBalancePieces] documents the only valid starting balance —
/// zero — without inventing persistence here.
///
/// Architecture rule (design.md): the domain layer has a strict inward
/// dependency direction and MUST NOT import `package:flutter/*` or `dart:io`.
library;

import 'package:wood_cft/domain/catalog.dart';

/// The seeded wood varieties, in the exact spelling required by Req 1.1.
///
/// Order and ids are stable so later layers (persistence, UI) can rely on them.
/// Mahogany=1, Kalani=2, Palajathi=3. All start [WoodVariety.active] = true.
const List<WoodVariety> kSeedVarieties = <WoodVariety>[
  WoodVariety(id: 1, name: 'Mahogany'),
  WoodVariety(id: 2, name: 'Kalani'),
  WoodVariety(id: 3, name: 'Palajathi'),
];

/// The seeded cross-sections (Req 1.2), width × thickness in inches.
///
/// 2 × 1 is a [WoodCategory.reaper]; 3 × 1, 4 × 1, 5 × 1, 6 × 1 and 7 × 1 are
/// [WoodCategory.plank]. Ids are stable (1..6 in ascending width order). These
/// are not `const` because [CrossSection] runs validation in its constructor.
final List<CrossSection> kSeedCrossSections = List<CrossSection>.unmodifiable(
  <CrossSection>[
    CrossSection(id: 1, widthIn: 2, thicknessIn: 1, category: WoodCategory.reaper),
    CrossSection(id: 2, widthIn: 3, thicknessIn: 1, category: WoodCategory.plank),
    CrossSection(id: 3, widthIn: 4, thicknessIn: 1, category: WoodCategory.plank),
    CrossSection(id: 4, widthIn: 5, thicknessIn: 1, category: WoodCategory.plank),
    CrossSection(id: 5, widthIn: 6, thicknessIn: 1, category: WoodCategory.plank),
    CrossSection(id: 6, widthIn: 7, thicknessIn: 1, category: WoodCategory.plank),
  ],
);

/// The one and only valid starting available quantity for every stock item on
/// first initialization: zero pieces (Requirement 1.12).
///
/// The seed does NOT materialize any `StockItem` balances — persisted balances
/// are a task 3 concern. This constant exists only to document, in code, that
/// the sole legitimate opening quantity is zero, so no later layer is tempted
/// to seed fictional stock.
const int kSeedStockItemBalancePieces = 0;

/// An immutable snapshot of the initial catalog seed.
///
/// Bundles the seeded [varieties] and [crossSections] together so a single
/// first-run routine can read the whole catalog from one place. It intentionally
/// carries no stock balances and no prices: those are absent by design
/// (Requirement 1.12) and are created later (tasks 3 and 7 respectively).
class CatalogSeed {
  /// Creates a catalog seed from the given varieties and cross-sections.
  const CatalogSeed({
    required this.varieties,
    required this.crossSections,
  });

  /// The seeded varieties (Mahogany, Kalani, Palajathi — Req 1.1).
  final List<WoodVariety> varieties;

  /// The seeded cross-sections (2×1 Reaper, 3×1…7×1 Plank — Req 1.2).
  final List<CrossSection> crossSections;

  /// Enumerates the stock items implied by the catalog: one record for every
  /// (variety × cross-section × length 2–9 ft) combination, each at the zero
  /// opening balance ([kSeedStockItemBalancePieces]).
  ///
  /// This is a pure projection used by first-run and tests to reason about the
  /// catalog's stock grid. It fabricates NO non-zero quantities — the returned
  /// items are identity+dimension only, and their conceptual balance is zero
  /// (Requirement 1.12). Ids are assigned deterministically so the enumeration
  /// is stable and repeatable.
  List<StockItem> enumerateStockItems() {
    final items = <StockItem>[];
    var id = 1;
    for (final variety in varieties) {
      for (final crossSection in crossSections) {
        for (var lengthFt = kMinLengthFt; lengthFt <= kMaxLengthFt; lengthFt++) {
          items.add(
            StockItem(
              id: id++,
              varietyId: variety.id,
              crossSectionId: crossSection.id,
              lengthFt: lengthFt,
            ),
          );
        }
      }
    }
    return List<StockItem>.unmodifiable(items);
  }
}

/// The initial catalog shipped on first run (Requirements 1.1, 1.2, 1.12).
final CatalogSeed kInitialCatalogSeed = CatalogSeed(
  varieties: kSeedVarieties,
  crossSections: kSeedCrossSections,
);
