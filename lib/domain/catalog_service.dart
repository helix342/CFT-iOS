/// Pure-Dart catalog mutation rules for the Wood CFT application (task 2.6).
///
/// This file implements the catalog mutation behaviour from
/// design.md -> Data Models ("deactivate, never delete" — 1.5, 1.6) and
/// Screen Flows -> Settings ("Varieties & sizes (add/rename/deactivate)").
/// It operates purely over in-memory collections of [WoodVariety]; persistence
/// (drift/SQLite, the movement ledger, pending-op queue) is a task 3 concern
/// and deliberately lives outside this layer.
///
/// The rules captured here (Requirements 1.3–1.7):
///  * add a new [WoodVariety] with a unique [WoodVariety.id] — pricing is NOT
///    inferred here (that is task 7);
///  * rename an existing variety, keeping its [WoodVariety.id] identity;
///  * deactivate a variety ([WoodVariety.active] = false) so it is excluded
///    from NEW receiving and NEW selling but is NEVER deleted, so historical
///    invoices keep their names (Requirements 1.5, 1.6);
///  * NEVER auto-merge two differently-named varieties — a rename that would
///    collide with another active variety's name is rejected rather than
///    merging records (Requirement 1.7; design "name unique while active").
///
/// Snapshot semantics (Requirement 1.6): a finalized invoice must preserve the
/// variety NAME exactly as issued. The domain RULE/helper for that lives here
/// ([CatalogService.snapshotVarietyName]); the actual invoice-snapshot write is
/// enforced at finalize (task 11). The `InvoiceLine.variety_name` text snapshot
/// in design.md -> Data Models is produced from this helper.
///
/// Architecture rule (design.md): the domain layer has a strict inward
/// dependency direction and MUST NOT import `package:flutter/*` or `dart:io`.
library;

import 'package:meta/meta.dart';

import 'package:wood_cft/domain/catalog.dart';

/// Error raised when a catalog mutation would violate a domain rule.
///
/// Used for: adding a variety whose [WoodVariety.id] already exists; renaming
/// or deactivating a variety that is not in the catalog; and — crucially — a
/// rename whose new name collides with another active variety, which the
/// System must NOT resolve by merging the two varieties (Requirement 1.7).
@immutable
class CatalogMutationError implements Exception {
  /// Creates a catalog mutation error with a human-readable [message].
  const CatalogMutationError(this.message);

  /// A description of why the mutation was rejected.
  final String message;

  @override
  String toString() => 'CatalogMutationError: $message';
}

/// Pure-Dart rules for mutating a collection of [WoodVariety] records.
///
/// Every method is a pure function over an input list: it returns a NEW list
/// and never mutates the argument, matching the immutable value-object style of
/// the rest of the domain layer. The caller (task 3 persistence) is responsible
/// for writing the result through the movement ledger / hosted DB.
///
/// Varieties are compared by name using a case-insensitive, trimmed match so
/// that "Mahogany" and "  mahogany " are treated as the same display name for
/// collision purposes (names are stored verbatim — Requirement 1.1 — but
/// uniqueness is enforced leniently to avoid accidental near-duplicates).
class CatalogService {
  /// Creates a stateless catalog service.
  const CatalogService();

  /// Normalises a variety [name] for case-insensitive collision comparison.
  static String _normalize(String name) => name.trim().toLowerCase();

  /// Returns only the active varieties from [varieties], preserving order.
  ///
  /// This is the filter used to populate NEW receiving and NEW selling flows;
  /// a deactivated variety ([WoodVariety.active] == false) is excluded here but
  /// is retained in the full catalog so historical records keep their names
  /// (Requirement 1.5).
  List<WoodVariety> activeVarieties(Iterable<WoodVariety> varieties) =>
      varieties.where((v) => v.active).toList(growable: false);

  /// Adds a brand-new [WoodVariety] with [id] and [name] to [varieties].
  ///
  /// The [id] must be unique within [varieties] (Requirement 1.3). The new
  /// variety is created `active: true`. Prices are NOT created or inferred here
  /// — pricing is a task 7 concern. A [CatalogMutationError] is thrown when the
  /// [id] already exists or when [name] (normalised) collides with an existing
  /// ACTIVE variety, since adding a duplicate must never merge records
  /// (Requirement 1.7).
  List<WoodVariety> addVariety(
    List<WoodVariety> varieties, {
    required int id,
    required String name,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const CatalogMutationError('a variety name must not be empty');
    }
    if (varieties.any((v) => v.id == id)) {
      throw CatalogMutationError('a variety with id $id already exists');
    }
    final normalized = _normalize(trimmed);
    final clash = varieties
        .any((v) => v.active && _normalize(v.name) == normalized);
    if (clash) {
      throw CatalogMutationError(
        'an active variety named "$trimmed" already exists; '
        'the System never auto-merges varieties',
      );
    }
    return List<WoodVariety>.unmodifiable(<WoodVariety>[
      ...varieties,
      WoodVariety(id: id, name: trimmed),
    ]);
  }

  /// Renames the variety identified by [id] to [newName] within [varieties].
  ///
  /// Identity is preserved: the returned variety keeps its [id] and
  /// [WoodVariety.active] flag; only the name changes (Requirement 1.4).
  /// Renaming to a name already held by ANOTHER active variety is rejected with
  /// a [CatalogMutationError] rather than merging the two varieties — the
  /// System never auto-merges (Requirement 1.7). Renaming a variety to its own
  /// name (ignoring case/whitespace) is allowed and simply normalises the
  /// stored spelling. A missing [id] throws a [CatalogMutationError].
  List<WoodVariety> renameVariety(
    List<WoodVariety> varieties, {
    required int id,
    required String newName,
  }) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw const CatalogMutationError('a variety name must not be empty');
    }
    _findById(varieties, id);
    final normalized = _normalize(trimmed);
    final clash = varieties.any(
      (v) => v.id != id && v.active && _normalize(v.name) == normalized,
    );
    if (clash) {
      throw CatalogMutationError(
        'cannot rename to "$trimmed": another active variety already uses '
        'that name; the System never auto-merges varieties',
      );
    }
    return List<WoodVariety>.unmodifiable(
      varieties
          .map((v) => v.id == id ? v.copyWith(name: trimmed) : v)
          .toList(growable: false),
    );
  }

  /// Deactivates the variety identified by [id] within [varieties].
  ///
  /// The variety is kept in the catalog with [WoodVariety.active] set to
  /// `false` — it is NEVER deleted (Requirement 1.5, design "deactivate, never
  /// delete"). After deactivation it is excluded from [activeVarieties] and so
  /// from NEW receiving and NEW selling, but existing invoices retain its name
  /// (Requirement 1.6). Deactivating an already-inactive variety is a no-op
  /// that still returns a valid list. A missing [id] throws a
  /// [CatalogMutationError].
  List<WoodVariety> deactivateVariety(
    List<WoodVariety> varieties, {
    required int id,
  }) {
    _findById(varieties, id);
    return List<WoodVariety>.unmodifiable(
      varieties
          .map((v) => v.id == id ? v.copyWith(active: false) : v)
          .toList(growable: false),
    );
  }

  /// Reactivates the variety identified by [id] within [varieties].
  ///
  /// This is the inverse of [deactivateVariety] and is included so a variety
  /// deactivated in Settings can be brought back without re-adding it (which
  /// would duplicate identity). Reactivation is rejected with a
  /// [CatalogMutationError] when another ACTIVE variety already holds the same
  /// name, since bringing it back must not collide/merge (Requirement 1.7).
  List<WoodVariety> reactivateVariety(
    List<WoodVariety> varieties, {
    required int id,
  }) {
    final target = _findById(varieties, id);
    final normalized = _normalize(target.name);
    final clash = varieties.any(
      (v) => v.id != id && v.active && _normalize(v.name) == normalized,
    );
    if (clash) {
      throw CatalogMutationError(
        'cannot reactivate "${target.name}": another active variety already '
        'uses that name; the System never auto-merges varieties',
      );
    }
    return List<WoodVariety>.unmodifiable(
      varieties
          .map((v) => v.id == id ? v.copyWith(active: true) : v)
          .toList(growable: false),
    );
  }

  /// Captures the variety NAME as issued, for an immutable invoice snapshot.
  ///
  /// This is the domain RULE/helper for snapshot semantics (Requirement 1.6):
  /// a finalized invoice records the variety's name AT THE TIME it was issued,
  /// so a later rename or deactivation never rewrites history. The returned
  /// string is what the finalize transaction (task 11) stores in
  /// `InvoiceLine.variety_name` (design.md -> Data Models). The name is
  /// captured verbatim (trimmed of surrounding whitespace only) to preserve the
  /// exact spelling given (Requirement 1.1).
  ///
  /// Capturing the name is independent of [WoodVariety.active]: a line may be
  /// snapshotted from a variety that is later deactivated, and the snapshot must
  /// still read the name as issued.
  String snapshotVarietyName(WoodVariety variety) => variety.name.trim();

  /// Returns the variety with [id] from [varieties], or throws if absent.
  WoodVariety _findById(Iterable<WoodVariety> varieties, int id) {
    for (final v in varieties) {
      if (v.id == id) {
        return v;
      }
    }
    throw CatalogMutationError('no variety with id $id in the catalog');
  }
}
