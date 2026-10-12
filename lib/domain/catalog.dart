/// Pure-Dart catalog domain models for the Wood CFT application (task 2.1).
///
/// This file defines the three catalog entities from design.md -> Data Models:
/// [WoodVariety], [CrossSection], and [StockItem]. They are the identity +
/// dimension layer that pricing, receiving, allocation, and billing all build
/// on. Persistence (balances, the movement ledger, drift/SQLite) is a task 3
/// concern and deliberately lives OUTSIDE these models — this layer stays
/// focused on identity and dimensions.
///
/// Unit discipline (Requirements 1.9, 1.11): width and thickness are measured
/// in INCHES, length is measured in FEET, and the two are NEVER interchanged.
/// The second cross-section dimension is the THICKNESS used later in the CFT
/// volume formula `W x T x L / 144` (Requirement 1.9; CalculationService,
/// task 2.3). That ordering is captured on [CrossSection.thicknessIn] and in
/// the inch label produced by [CrossSection.inchLabel].
///
/// Architecture rule (design.md): the domain layer has a strict inward
/// dependency direction and MUST NOT import `package:flutter/*` or `dart:io`.
library;

import 'package:meta/meta.dart';

/// Classification of a [CrossSection] as a reaper or a plank.
///
/// The category fixes the whole-sale unit: reapers trade only in whole bunches
/// of exactly 10 pieces, planks trade in whole pieces (Requirements 3.1, 3.3).
/// Stored as metadata on the cross-section (design.md -> Data Models).
enum WoodCategory {
  /// A reaper cross-section. Received, allocated, and sold in whole bunches of
  /// exactly 10 pieces only (Requirement 3.1).
  reaper,

  /// A plank cross-section. Counted and sold by whole pieces (Requirement 3.3).
  plank;

  /// The number of pieces in one whole sale unit for this category.
  ///
  /// A reaper's sale unit is a bunch of 10 pieces; a plank's sale unit is a
  /// single piece. This is the authoritative source for [CrossSection.bunchSize].
  int get bunchSize => this == WoodCategory.reaper ? 10 : 1;
}

/// The inclusive lower bound for a [StockItem.lengthFt] in feet (Req 1.10).
const int kMinLengthFt = 2;

/// The inclusive upper bound for a [StockItem.lengthFt] in feet (Req 1.10).
const int kMaxLengthFt = 9;

/// A named timber type such as Mahogany, Kalani, or Palajathi.
///
/// Varieties may be added, renamed, or deactivated (Requirement 1.3–1.5); the
/// mutation rules themselves land in task 2.6. This model carries only the
/// identity ([id]), the [name] (stored with its exact spelling as given —
/// Requirement 1.1), and the [active] flag used to hide a deactivated variety
/// from new receiving and new selling (Requirement 1.5).
@immutable
class WoodVariety {
  /// Creates a wood variety with the given [id] and [name].
  ///
  /// [name] is stored verbatim; the caller is responsible for the exact
  /// spelling (Requirement 1.1). [active] defaults to `true`.
  const WoodVariety({
    required this.id,
    required this.name,
    this.active = true,
  });

  /// Stable identity for this variety (primary key in the data layer).
  final int id;

  /// The display name, stored with the exact spelling it was given
  /// (Requirement 1.1). Renaming is a task 2.6 concern.
  final String name;

  /// Whether this variety is available for new receiving and new selling.
  ///
  /// A deactivated variety ([active] == false) is hidden from new work but is
  /// never deleted, so historical invoices keep their variety name as issued
  /// (Requirements 1.5, 1.6).
  final bool active;

  /// Returns a copy of this variety with the given fields replaced.
  WoodVariety copyWith({int? id, String? name, bool? active}) => WoodVariety(
    id: id ?? this.id,
    name: name ?? this.name,
    active: active ?? this.active,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WoodVariety &&
          id == other.id &&
          name == other.name &&
          active == other.active);

  @override
  int get hashCode => Object.hash(id, name, active);

  @override
  String toString() =>
      'WoodVariety(id: $id, name: $name, active: $active)';
}

/// A width-by-thickness timber profile measured in inches (e.g. "2 x 1 in").
///
/// The FIRST dimension is the width ([widthIn]); the SECOND dimension is the
/// thickness ([thicknessIn]) — the dimension used in the CFT volume formula
/// `W x T x L / 144` later in CalculationService (Requirement 1.9). Both
/// dimensions are in INCHES; length (feet) belongs on [StockItem] and is never
/// stored here, keeping inches and feet strictly distinct (Requirement 1.11).
@immutable
class CrossSection {
  /// Creates a cross-section with the given dimensions and classification.
  ///
  /// [widthIn] and [thicknessIn] are in inches and must be positive.
  /// [bunchSize] defaults to the value implied by [category] (10 for a reaper,
  /// 1 for a plank) and, if supplied, must agree with the category.
  CrossSection({
    required this.id,
    required this.widthIn,
    required this.thicknessIn,
    required this.category,
    int? bunchSize,
    this.active = true,
  }) : bunchSize = bunchSize ?? category.bunchSize {
    if (widthIn <= 0) {
      throw ArgumentError.value(
        widthIn,
        'widthIn',
        'cross-section width (inches) must be positive',
      );
    }
    if (thicknessIn <= 0) {
      throw ArgumentError.value(
        thicknessIn,
        'thicknessIn',
        'cross-section thickness (inches) must be positive',
      );
    }
    if (this.bunchSize != category.bunchSize) {
      throw ArgumentError.value(
        this.bunchSize,
        'bunchSize',
        'bunch size must be ${category.bunchSize} for ${category.name} '
            '(10 for Reaper, 1 for Plank)',
      );
    }
  }

  /// Stable identity for this cross-section (primary key in the data layer).
  final int id;

  /// The first dimension (width) in INCHES.
  final int widthIn;

  /// The second dimension (thickness) in INCHES.
  ///
  /// This is the dimension used in the CFT volume formula
  /// `width_in x thickness_in x length_ft / 144` (Requirement 1.9).
  final int thicknessIn;

  /// Whether this cross-section is a reaper or a plank (stored as metadata).
  final WoodCategory category;

  /// The number of pieces in one whole sale unit: 10 for a reaper, 1 for a
  /// plank (Requirements 3.1, 3.3). Always consistent with [category].
  final int bunchSize;

  /// Whether this cross-section is available for new receiving and selling.
  final bool active;

  /// The human-readable inch label in the form "W x T in", e.g. `"2 × 1 in"`
  /// (Requirement 1.8). The width is first, the thickness second, matching the
  /// order used by the volume formula.
  String get inchLabel => '$widthIn × $thicknessIn in';

  /// Returns a copy of this cross-section with the given fields replaced.
  ///
  /// When [category] changes without an explicit [bunchSize], the bunch size
  /// is recomputed from the new category to stay consistent.
  CrossSection copyWith({
    int? id,
    int? widthIn,
    int? thicknessIn,
    WoodCategory? category,
    int? bunchSize,
    bool? active,
  }) {
    final newCategory = category ?? this.category;
    return CrossSection(
      id: id ?? this.id,
      widthIn: widthIn ?? this.widthIn,
      thicknessIn: thicknessIn ?? this.thicknessIn,
      category: newCategory,
      bunchSize: bunchSize ?? (category != null ? newCategory.bunchSize : this.bunchSize),
      active: active ?? this.active,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CrossSection &&
          id == other.id &&
          widthIn == other.widthIn &&
          thicknessIn == other.thicknessIn &&
          category == other.category &&
          bunchSize == other.bunchSize &&
          active == other.active);

  @override
  int get hashCode =>
      Object.hash(id, widthIn, thicknessIn, category, bunchSize, active);

  @override
  String toString() =>
      'CrossSection(id: $id, label: $inchLabel, category: ${category.name}, '
      'bunchSize: $bunchSize, active: $active)';
}

/// A persisted inventory record keyed by variety + cross-section + length.
///
/// The business key is the triple ([varietyId], [crossSectionId], [lengthFt]);
/// the data layer enforces a uniqueness constraint on it (design.md -> Data
/// Models). [lengthFt] is in FEET and is constrained to the inclusive range
/// 2–9 (Requirement 1.10); width and thickness (inches) live on the referenced
/// [CrossSection] and are never duplicated here, keeping feet and inches
/// distinct (Requirement 1.11).
///
/// This domain model intentionally holds identity + dimension only. The
/// confirmed/pending piece balances and the movement ledger are persistence
/// concerns handled in task 3 and are deliberately absent here.
@immutable
class StockItem {
  /// Creates a stock item for the given variety, cross-section, and length.
  ///
  /// Throws a [RangeError] when [lengthFt] is outside the inclusive 2–9 ft
  /// range (Requirement 1.10).
  StockItem({
    required this.id,
    required this.varietyId,
    required this.crossSectionId,
    required this.lengthFt,
  }) {
    if (lengthFt < kMinLengthFt || lengthFt > kMaxLengthFt) {
      throw RangeError.range(
        lengthFt,
        kMinLengthFt,
        kMaxLengthFt,
        'lengthFt',
        'length (feet) must be within $kMinLengthFt–$kMaxLengthFt inclusive',
      );
    }
  }

  /// Stable identity for this stock item (primary key in the data layer).
  final int id;

  /// Identity of the owning [WoodVariety] (part of the business key).
  final int varietyId;

  /// Identity of the owning [CrossSection] (part of the business key).
  final int crossSectionId;

  /// The piece length in FEET, constrained to 2–9 inclusive (Requirement 1.10).
  final int lengthFt;

  /// Returns a copy of this stock item with the given fields replaced.
  ///
  /// A replacement [lengthFt] is re-validated against the 2–9 ft range.
  StockItem copyWith({
    int? id,
    int? varietyId,
    int? crossSectionId,
    int? lengthFt,
  }) => StockItem(
    id: id ?? this.id,
    varietyId: varietyId ?? this.varietyId,
    crossSectionId: crossSectionId ?? this.crossSectionId,
    lengthFt: lengthFt ?? this.lengthFt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockItem &&
          id == other.id &&
          varietyId == other.varietyId &&
          crossSectionId == other.crossSectionId &&
          lengthFt == other.lengthFt);

  @override
  int get hashCode =>
      Object.hash(id, varietyId, crossSectionId, lengthFt);

  @override
  String toString() =>
      'StockItem(id: $id, varietyId: $varietyId, '
      'crossSectionId: $crossSectionId, lengthFt: $lengthFt)';
}
