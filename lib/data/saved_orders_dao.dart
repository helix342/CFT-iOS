/// Persistence for saveable, resumable orders (app-ux-revamp Requirement 4).
///
/// A saved order is a `DraftOrders` row (schema v2) plus its staged
/// `DraftOrderRequests`; it survives app restart so the owner can park an order
/// and resume it later (Requirement 4.2, 4.4; OD-1). This DAO REUSES the
/// existing draft tables — no new saved-order table is introduced.
///
/// It exposes the lifecycle the order workflow drives: create a draft, replace
/// its staged exact-quantity request lines, load the resumable drafts (those
/// still in `draft` / `review` / `approved`), load one draft with its requests,
/// advance the status, attach the produced invoice id when sold, and delete.
/// Every write touches `updatedAt` so the resumable list can sort newest-first.
library;

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/tables.dart';

/// One staged exact-quantity request line for a saved order.
///
/// The saveable-order surface stages concrete SKUs (variety + cross-section +
/// length + whole-unit quantity), so this DAO persists them as
/// [RequestType.exactQty] `DraftOrderRequests` rows.
@immutable
class SavedRequestLine {
  /// Creates a staged request line.
  const SavedRequestLine({
    required this.varietyId,
    required this.crossSectionId,
    required this.lengthFt,
    required this.qty,
  });

  /// The owning variety id.
  final int varietyId;

  /// The pinned cross-section id.
  final int crossSectionId;

  /// The piece length in feet.
  final int lengthFt;

  /// The whole-unit quantity (bunches for a reaper, pieces for a plank).
  final int qty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedRequestLine &&
          other.varietyId == varietyId &&
          other.crossSectionId == crossSectionId &&
          other.lengthFt == lengthFt &&
          other.qty == qty);

  @override
  int get hashCode => Object.hash(varietyId, crossSectionId, lengthFt, qty);
}

/// One staged target-CFT request line for a saved order.
///
/// Target requests carry no whole-unit quantity (the allocator derives units);
/// instead they persist the structured constraints the owner chose plus the
/// exact target CFT as an integer numerator / denominator pair so it round-trips
/// without floating-point drift. [requestType] is one of the three target-CFT
/// shapes (`RequestType.targetCftFixedLen`,
/// `RequestType.targetCftFlexCrossSection`, `RequestType.targetCftFlexCategory`).
@immutable
class SavedTargetLine {
  /// Creates a staged target request line.
  const SavedTargetLine({
    required this.requestType,
    required this.varietyId,
    required this.targetCftNum,
    required this.targetCftDen,
    this.crossSectionId,
    this.category,
    this.lengthFt,
  });

  /// Which target-CFT shape this line is.
  final RequestType requestType;

  /// The owning variety id.
  final int varietyId;

  /// The exact target-CFT numerator.
  final BigInt targetCftNum;

  /// The exact target-CFT denominator (strictly positive).
  final BigInt targetCftDen;

  /// The pinned cross-section id (for the two cross-section shapes).
  final int? crossSectionId;

  /// The pinned category (for the flexible-category shape).
  final CategoryKind? category;

  /// The pinned length in feet (for the fixed-length shape).
  final int? lengthFt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedTargetLine &&
          other.requestType == requestType &&
          other.varietyId == varietyId &&
          other.targetCftNum == targetCftNum &&
          other.targetCftDen == targetCftDen &&
          other.crossSectionId == crossSectionId &&
          other.category == category &&
          other.lengthFt == lengthFt);

  @override
  int get hashCode => Object.hash(
        requestType,
        varietyId,
        targetCftNum,
        targetCftDen,
        crossSectionId,
        category,
        lengthFt,
      );
}

/// A loaded saved order: its draft row plus its staged request lines.
@immutable
class SavedOrder {
  /// Creates a loaded saved order.
  const SavedOrder({
    required this.draft,
    required this.lines,
    this.targets = const [],
  });

  /// The persisted draft row (carries status, title, customer, timestamps).
  final DraftOrderRow draft;

  /// The staged exact-quantity request lines for this order, in insertion
  /// order.
  final List<SavedRequestLine> lines;

  /// The staged target-CFT request lines for this order, in insertion order.
  final List<SavedTargetLine> targets;
}

/// The statuses that make an order resumable from the Orders tab (Req 4.3).
const List<DraftStatus> kResumableStatuses = [
  DraftStatus.draft,
  DraftStatus.review,
  DraftStatus.approved,
];

/// Data-layer access to saveable, resumable orders.
class SavedOrdersDao {
  /// Creates the DAO over [db].
  const SavedOrdersDao(this.db);

  /// The local cache database.
  final AppDatabase db;

  /// Creates a new saved order in `draft` status and returns its id.
  Future<int> createDraft({
    String? title,
    String? customerName,
    String? customerPhone,
    DateTime? now,
  }) {
    final ts = (now ?? DateTime.now()).toUtc();
    return db.into(db.draftOrders).insert(
          DraftOrdersCompanion.insert(
            status: DraftStatus.draft,
            createdAt: ts,
            title: Value(title),
            customerName: Value(customerName),
            customerPhone: Value(customerPhone),
            updatedAt: Value(ts),
          ),
        );
  }

  /// Replaces the staged request lines for [draftId] with [lines] (exact
  /// quantity) and [targets] (target CFT).
  ///
  /// Runs in one transaction: deletes the existing requests then inserts the
  /// new set, and touches `updatedAt`. Exact-quantity lines persist as
  /// [RequestType.exactQty]; each target persists with its real target-CFT
  /// request type and its exact numerator / denominator.
  Future<void> replaceRequestLines(
    int draftId,
    List<SavedRequestLine> lines, {
    List<SavedTargetLine> targets = const [],
    DateTime? now,
  }) {
    return db.transaction(() async {
      await (db.delete(db.draftOrderRequests)
            ..where((r) => r.draftId.equals(draftId)))
          .go();
      for (final line in lines) {
        await db.into(db.draftOrderRequests).insert(
              DraftOrderRequestsCompanion.insert(
                draftId: draftId,
                requestType: RequestType.exactQty,
                varietyId: line.varietyId,
                crossSectionId: Value(line.crossSectionId),
                lengthFt: Value(line.lengthFt),
                qty: Value(line.qty),
              ),
            );
      }
      for (final target in targets) {
        await db.into(db.draftOrderRequests).insert(
              DraftOrderRequestsCompanion.insert(
                draftId: draftId,
                requestType: target.requestType,
                varietyId: target.varietyId,
                crossSectionId: Value(target.crossSectionId),
                category: Value(target.category),
                lengthFt: Value(target.lengthFt),
                targetCftNum: Value(target.targetCftNum.toInt()),
                targetCftDen: Value(target.targetCftDen.toInt()),
              ),
            );
      }
      await _touch(draftId, now);
    });
  }

  /// Loads the resumable saved orders (status in {draft, review, approved}),
  /// newest-updated first.
  Future<List<DraftOrderRow>> loadResumable() {
    final statuses = kResumableStatuses.map((s) => s.index).toList();
    return (db.select(db.draftOrders)
          ..where((d) => d.status.isIn(statuses))
          ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)]))
        .get();
  }

  /// Loads one saved order with its staged request lines, or null when the
  /// draft does not exist.
  Future<SavedOrder?> loadOne(int draftId) async {
    final draft = await (db.select(db.draftOrders)
          ..where((d) => d.id.equals(draftId)))
        .getSingleOrNull();
    if (draft == null) return null;
    final rows = await (db.select(db.draftOrderRequests)
          ..where((r) => r.draftId.equals(draftId))
          ..orderBy([(r) => OrderingTerm.asc(r.id)]))
        .get();
    final lines = <SavedRequestLine>[];
    final targets = <SavedTargetLine>[];
    for (final r in rows) {
      if (r.requestType == RequestType.exactQty) {
        lines.add(
          SavedRequestLine(
            varietyId: r.varietyId,
            crossSectionId: r.crossSectionId ?? 0,
            lengthFt: r.lengthFt ?? 0,
            qty: r.qty ?? 0,
          ),
        );
      } else {
        targets.add(
          SavedTargetLine(
            requestType: r.requestType,
            varietyId: r.varietyId,
            crossSectionId: r.crossSectionId,
            category: r.category,
            lengthFt: r.lengthFt,
            targetCftNum: BigInt.from(r.targetCftNum ?? 0),
            targetCftDen: BigInt.from(r.targetCftDen ?? 1),
          ),
        );
      }
    }
    return SavedOrder(
      draft: draft,
      lines: List<SavedRequestLine>.unmodifiable(lines),
      targets: List<SavedTargetLine>.unmodifiable(targets),
    );
  }

  /// Updates the status of [draftId] and touches `updatedAt`.
  Future<void> updateStatus(
    int draftId,
    DraftStatus status, {
    DateTime? now,
  }) {
    return (db.update(db.draftOrders)..where((d) => d.id.equals(draftId)))
        .write(
      DraftOrdersCompanion(
        status: Value(status),
        updatedAt: Value((now ?? DateTime.now()).toUtc()),
      ),
    );
  }

  /// Attaches the produced [invoiceId] to [draftId] (set when sold) and
  /// touches `updatedAt`.
  Future<void> attachInvoice(
    int draftId,
    int invoiceId, {
    DateTime? now,
  }) {
    return (db.update(db.draftOrders)..where((d) => d.id.equals(draftId)))
        .write(
      DraftOrdersCompanion(
        invoiceId: Value(invoiceId),
        updatedAt: Value((now ?? DateTime.now()).toUtc()),
      ),
    );
  }

  /// Deletes a saved order and its staged request lines.
  Future<void> delete(int draftId) {
    return db.transaction(() async {
      await (db.delete(db.draftOrderRequests)
            ..where((r) => r.draftId.equals(draftId)))
          .go();
      await (db.delete(db.draftOrders)..where((d) => d.id.equals(draftId)))
          .go();
    });
  }

  Future<void> _touch(int draftId, DateTime? now) {
    return (db.update(db.draftOrders)..where((d) => d.id.equals(draftId)))
        .write(
      DraftOrdersCompanion(
        updatedAt: Value((now ?? DateTime.now()).toUtc()),
      ),
    );
  }
}
