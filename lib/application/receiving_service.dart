/// The receiving-session lifecycle service and immediate local commit (task
/// 5.1).
///
/// [ReceivingService] drives the **local-only receiving entry** boundary from
/// design.md -> Transaction Boundaries & Sync (local-only a). It owns the
/// `ReceiptSessions` lifecycle (create / resume the single active session,
/// finish it) and performs each receiving entry as ONE atomic local write:
///
///   * insert a `ReceiptEntries` row;
///   * append a `StockMovements` row (type Receive, `sync_state = Pending`)
///     via `StockLedgerDao`, which increments the stock item's PENDING balance;
///   * enqueue a `PendingOperations` row with a stable idempotency key via
///     `PendingOperationQueue`, composed into the SAME transaction.
///
/// Either all three writes commit, or none do. The received quantity lands in
/// `pending_balance_pieces` and is shown as `Pending_Receiving_Stock` â€” it is
/// NOT sellable until the sync engine (task 4.3) confirms it (5.6a, 19.8,
/// 21.27). `StockLedgerDao` already keeps pending receives out of the confirmed
/// (sellable) balance; this service just records them with
/// `SyncState.pending`.
///
/// ### At most one active session
///
/// A new receipt is created only when there is no active session; otherwise the
/// existing active session is resumed. This mirrors the owner "create or resume
/// an active Receipt" requirement (5.1) and makes resume-after-restart a
/// read of the single active row (task 5.3 builds the UI on top of this).
///
/// ### Exactly-once (no double-add)
///
/// Every receiving operation carries a stable `idempotency_key`. The same key
/// is used for the `ReceiptEntries` row (unique), the `StockMovements` row
/// (unique, enforced by `StockLedgerDao`), and the `PendingOperations` row
/// (unique, enforced by `PendingOperationQueue`). Repeating an operation â€” a
/// retry, a double-tap, a resumed or finished receipt â€” re-presents the same
/// key and is a no-op, so stock is added exactly once (5.8, 5.9, 21.6).
/// Finishing a session only flips its status; it never re-applies the entries
/// already recorded.
///
/// Architecture rule (design.md): this is an application-layer service over the
/// data layer. It reads the catalog `CrossSection` (for the reaper bunch size)
/// through the shared `CalculationService.pieceEquivalent`, so the
/// bunch->pieces conversion has a single definition.
library;

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/pending_operation_queue.dart';
import 'package:wood_cft/data/stock_ledger_dao.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/domain/catalog.dart';

/// The outcome of recording a receiving entry.
enum ReceivingOutcome {
  /// The entry was recorded: a `ReceiptEntries` row, a pending
  /// `StockMovements` row, and a `PendingOperations` row were written in one
  /// transaction and the pending balance was incremented.
  recorded,

  /// The idempotency key already existed; the call was a no-op so stock is
  /// added exactly once (5.8, 5.9, 21.6).
  duplicateIgnored,
}

/// The result of recording (or resuming) a receiving entry.
@immutable
class ReceivingEntryResult {
  /// Creates a result.
  const ReceivingEntryResult({
    required this.sessionId,
    required this.outcome,
    required this.piecesDelta,
  });

  /// The active session the entry was recorded into.
  final int sessionId;

  /// Whether the entry was newly recorded or ignored as a duplicate.
  final ReceivingOutcome outcome;

  /// The resolved whole-piece delta the entry represents (bunches x bunchSize
  /// for reapers, or the piece count for planks).
  final int piecesDelta;

  @override
  String toString() =>
      'ReceivingEntryResult(sessionId: $sessionId, outcome: $outcome, '
      'piecesDelta: $piecesDelta)';
}

/// Drives the receiving-session lifecycle and the immediate local commit.
class ReceivingService {
  /// Creates a receiving service over [_db].
  ///
  /// A shared [CalculationService] may be supplied; otherwise a default
  /// `const` instance is used (the service is stateless).
  ReceivingService(
    this._db, {
    CalculationService calculationService = const CalculationService(),
  })  : _ledger = StockLedgerDao(_db),
        _queue = PendingOperationQueue(_db),
        _calc = calculationService;

  final AppDatabase _db;
  final StockLedgerDao _ledger;
  final PendingOperationQueue _queue;
  final CalculationService _calc;

  /// Returns the single active `ReceiptSessions` row, or null if none is open.
  ///
  /// There is at most one active session at a time (see [startOrResumeSession]).
  Future<ReceiptSessionRow?> activeSession() {
    return (_db.select(_db.receiptSessions)
          ..where((s) => s.status.equalsValue(ReceiptStatus.active))
          ..orderBy([(s) => OrderingTerm.asc(s.id)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Creates a new active receipt, or resumes the existing active one.
  ///
  /// If an active session already exists it is returned unchanged (resume);
  /// otherwise a fresh active session is created. This keeps at most one active
  /// session, so resume-after-restart (task 5.3) is a read of the active row
  /// and finishing is unambiguous (5.1).
  Future<ReceiptSessionRow> startOrResumeSession({DateTime? startedAt}) async {
    return _db.transaction(() async {
      final existing = await activeSession();
      if (existing != null) return existing;

      final started = (startedAt ?? DateTime.now()).toUtc();
      final id = await _db.into(_db.receiptSessions).insert(
            ReceiptSessionsCompanion.insert(
              status: ReceiptStatus.active,
              startedAt: started,
            ),
          );
      return (_db.select(_db.receiptSessions)..where((s) => s.id.equals(id)))
          .getSingle();
    });
  }

  /// Records one receiving entry into the active receipt as a single atomic
  /// local write (design.md -> local-only a).
  ///
  /// Resolves the whole-piece delta from [qtyInput] and [unit]: for a reaper
  /// ([InputUnit.bunch]) the delta is `qtyInput x CrossSection.bunchSize` via
  /// [CalculationService.pieceEquivalent]; for a plank ([InputUnit.piece]) the
  /// delta is `qtyInput` pieces. Within ONE transaction it then inserts the
  /// `ReceiptEntries` row, appends a pending `StockMovements` row (incrementing
  /// the PENDING balance), and enqueues a `PendingOperations` row â€” all keyed by
  /// the same [idempotencyKey].
  ///
  /// Repeating the same [idempotencyKey] (retry, double-tap, resume, finish) is
  /// a no-op and returns [ReceivingOutcome.duplicateIgnored], so stock is added
  /// exactly once (5.8, 5.9, 21.6).
  ///
  /// [crossSection] must be the cross-section of [stockItemId]; it supplies the
  /// bunch size for the reaper conversion. Pass [occurredAt] to pin the
  /// movement/entry time (defaults to now, stored UTC).
  ///
  /// Throws an [ArgumentError] when [qtyInput] is not positive, or when
  /// [unit] is [InputUnit.bunch] for a non-reaper cross-section.
  Future<ReceivingEntryResult> recordReceivingEntry({
    required int stockItemId,
    required CrossSection crossSection,
    required int qtyInput,
    required InputUnit unit,
    required String idempotencyKey,
    MovementType movementType = MovementType.receive,
    SyncState syncState = SyncState.pending,
    DateTime? occurredAt,
  }) async {
    if (qtyInput <= 0) {
      throw ArgumentError.value(
        qtyInput,
        'qtyInput',
        'receiving quantity must be a positive whole number',
      );
    }
    if (unit == InputUnit.bunch && crossSection.category != WoodCategory.reaper) {
      throw ArgumentError.value(
        unit,
        'unit',
        'bunch input is only valid for a reaper cross-section',
      );
    }

    // Resolve the whole-piece delta. Reapers are entered in bunches and the
    // single bunch->pieces conversion lives in CalculationService; planks are
    // entered directly in pieces.
    final piecesDelta = unit == InputUnit.bunch
        ? _calc.pieceEquivalent(crossSection, qtyInput)
        : qtyInput;

    final occurred = (occurredAt ?? DateTime.now()).toUtc();

    return _db.transaction(() async {
      final session = await startOrResumeSession(startedAt: occurred);

      // Idempotency gate: if this key was already recorded (as a receipt
      // entry), the operation is a no-op so stock is added exactly once.
      final existingEntry = await (_db.select(_db.receiptEntries)
            ..where((e) => e.idempotencyKey.equals(idempotencyKey)))
          .getSingleOrNull();
      if (existingEntry != null) {
        return ReceivingEntryResult(
          sessionId: session.id,
          outcome: ReceivingOutcome.duplicateIgnored,
          piecesDelta: existingEntry.piecesDelta,
        );
      }

      // 1) Insert the receipt entry (unique idempotency key).
      final entryId = await _db.into(_db.receiptEntries).insert(
            ReceiptEntriesCompanion.insert(
              receiptId: session.id,
              stockItemId: stockItemId,
              qtyInput: qtyInput,
              unit: unit,
              piecesDelta: piecesDelta,
              idempotencyKey: idempotencyKey,
              createdAt: occurred,
            ),
          );

      // 2) Append the pending movement -> increments PENDING balance only, so
      //    the quantity is Pending_Receiving_Stock and not sellable (5.6a,
      //    19.8, 21.27). StockLedgerDao enforces the unique movement key.
      final movementOutcome = await _ledger.recordMovement(
        stockItemId: stockItemId,
        type: movementType,
        deltaPieces: piecesDelta,
        idempotencyKey: idempotencyKey,
        syncState: syncState,
        occurredAt: occurred,
        receiptEntryId: entryId,
      );

      // 3) Enqueue the pending op in the SAME transaction (executor: _db), so
      //    the local write + enqueue commit atomically (5.6, 19.7).
      await _queue.enqueue(
        opType: OpType.receiveEntry,
        payload: _receivePayload(
          receiptEntryId: entryId,
          stockItemId: stockItemId,
          piecesDelta: piecesDelta,
          movementType: movementType,
        ),
        idempotencyKey: idempotencyKey,
        enqueuedAt: occurred,
        executor: _db,
      );

      // A duplicate movement (should not happen when the entry was new, but is
      // defensive) is reported as a duplicate without claiming a fresh record.
      final outcome = movementOutcome == MovementOutcome.applied
          ? ReceivingOutcome.recorded
          : ReceivingOutcome.duplicateIgnored;

      return ReceivingEntryResult(
        sessionId: session.id,
        outcome: outcome,
        piecesDelta: piecesDelta,
      );
    });
  }

  /// Finishes the active receipt by flipping its status to
  /// [ReceiptStatus.finished] and stamping `finished_at`.
  ///
  /// Finishing NEVER re-applies the entries already recorded â€” the stock
  /// effects were committed at entry time â€” so finishing (or re-finishing) does
  /// not double-add stock (21.6). Returns the finished session, or null when
  /// there is no active session to finish. A session that is already finished
  /// is returned unchanged.
  Future<ReceiptSessionRow?> finishActiveSession({DateTime? finishedAt}) async {
    return _db.transaction(() async {
      final session = await activeSession();
      if (session == null) return null;

      await (_db.update(_db.receiptSessions)
            ..where((s) => s.id.equals(session.id)))
          .write(
        ReceiptSessionsCompanion(
          status: const Value(ReceiptStatus.finished),
          finishedAt: Value((finishedAt ?? DateTime.now()).toUtc()),
        ),
      );
      return (_db.select(_db.receiptSessions)
            ..where((s) => s.id.equals(session.id)))
          .getSingle();
    });
  }

  /// Reads the entries recorded into [sessionId] in insertion order.
  Future<List<ReceiptEntryRow>> entriesForSession(int sessionId) {
    return (_db.select(_db.receiptEntries)
          ..where((e) => e.receiptId.equals(sessionId))
          ..orderBy([(e) => OrderingTerm.asc(e.id)]))
        .get();
  }

  /// Promotes every currently-pending stock movement to confirmed (local-only
  /// mode: no cloud sync, so received stock must become available at once).
  ///
  /// Idempotent: a movement that is already confirmed is skipped by
  /// `StockLedgerDao.confirmMovement`. Returns the number of movements
  /// promoted. Called once at startup so stock received before this behavior
  /// existed also becomes available without a reinstall.
  Future<int> confirmAllPending() async {
    final pending = await (_db.select(_db.stockMovements)
          ..where((m) => m.syncState.equalsValue(SyncState.pending)))
        .get();
    for (final m in pending) {
      await _ledger.confirmMovement(m.idempotencyKey);
    }
    return pending.length;
  }

  /// Builds the durable queue payload for a receiving entry. Kept minimal and
  /// stable: the sync engine (task 4.3) re-applies the movement by its own
  /// idempotency key, so the payload only needs to identify the local write.
  String _receivePayload({
    required int receiptEntryId,
    required int stockItemId,
    required int piecesDelta,
    required MovementType movementType,
  }) {
    return '{"kind":"${movementType.name}",'
        '"receiptEntryId":$receiptEntryId,'
        '"stockItemId":$stockItemId,'
        '"piecesDelta":$piecesDelta}';
  }
}
