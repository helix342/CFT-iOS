/// Unit tests for the receiving-session lifecycle and immediate local commit
/// (task 5.1).
///
/// These boot an in-memory [AppDatabase] (so they run under `flutter test` on
/// Windows with no device) and exercise [ReceivingService]:
///
///   * receiving 3 bunches of a 2 x 1 reaper @6 ft adds 30 pieces to the
///     PENDING balance (not confirmed / not sellable) and tracks exactly
///     (Req 21.27 intent; design.md -> local-only a);
///   * resuming returns the SAME active session (at most one active, 5.1);
///   * finishing the session does NOT double-add stock (Req 21.6 intent);
///   * repeating the same idempotency key is a no-op (no double add; 5.8, 5.9).
///
/// A pending receive lands in `pending_balance_pieces` with
/// `confirmed_balance_pieces` unchanged, so pending stock is never counted as
/// sellable/confirmed (Req 21.27 intent).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wood_cft/application/receiving_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/stock_ledger_dao.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/domain/catalog.dart';

/// Seeds a reaper 2 x 1 variety + cross-section + stock item at [lengthFt] and
/// returns the stock item id together with the domain [CrossSection] used for
/// the bunch->pieces conversion.
Future<({int stockItemId, CrossSection crossSection})> _seedReaper(
  AppDatabase db, {
  int lengthFt = 6,
}) async {
  final varietyId = await db.into(db.woodVarieties).insert(
        WoodVarietiesCompanion.insert(
          name: 'Mahogany',
          createdAt: DateTime.utc(2024, 1, 1),
        ),
      );
  final crossSectionId = await db.into(db.crossSections).insert(
        CrossSectionsCompanion.insert(
          widthIn: 2,
          thicknessIn: 1,
          category: CategoryKind.reaper,
          bunchSize: 10,
        ),
      );
  final stockItemId = await db.into(db.stockItems).insert(
        StockItemsCompanion.insert(
          varietyId: varietyId,
          crossSectionId: crossSectionId,
          lengthFt: lengthFt,
        ),
      );
  final crossSection = CrossSection(
    id: crossSectionId,
    widthIn: 2,
    thicknessIn: 1,
    category: WoodCategory.reaper,
  );
  return (stockItemId: stockItemId, crossSection: crossSection);
}

/// Seeds a plank 3 x 1 variety + cross-section + stock item and returns ids.
Future<({int stockItemId, CrossSection crossSection})> _seedPlank(
  AppDatabase db, {
  int lengthFt = 6,
}) async {
  final varietyId = await db.into(db.woodVarieties).insert(
        WoodVarietiesCompanion.insert(
          name: 'Kalani',
          createdAt: DateTime.utc(2024, 1, 1),
        ),
      );
  final crossSectionId = await db.into(db.crossSections).insert(
        CrossSectionsCompanion.insert(
          widthIn: 3,
          thicknessIn: 1,
          category: CategoryKind.plank,
          bunchSize: 1,
        ),
      );
  final stockItemId = await db.into(db.stockItems).insert(
        StockItemsCompanion.insert(
          varietyId: varietyId,
          crossSectionId: crossSectionId,
          lengthFt: lengthFt,
        ),
      );
  final crossSection = CrossSection(
    id: crossSectionId,
    widthIn: 3,
    thicknessIn: 1,
    category: WoodCategory.plank,
  );
  return (stockItemId: stockItemId, crossSection: crossSection);
}

void main() {
  group('ReceivingService — session lifecycle and immediate local commit', () {
    late AppDatabase db;
    late ReceivingService service;
    late StockLedgerDao ledger;

    setUp(() {
      db = openInMemoryDatabase();
      service = ReceivingService(db);
      ledger = StockLedgerDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
        'receiving 3 bunches of a 2 x 1 reaper @6 ft adds 30 pieces to PENDING '
        '(not confirmed/sellable) and tracks exactly (Req 21.27)', () async {
      final seed = await _seedReaper(db);

      final result = await service.recordReceivingEntry(
        stockItemId: seed.stockItemId,
        crossSection: seed.crossSection,
        qtyInput: 3,
        unit: InputUnit.bunch,
        idempotencyKey: 'recv-reaper-1',
      );

      expect(result.outcome, ReceivingOutcome.recorded);
      expect(result.piecesDelta, 30);

      // 30 pieces land in PENDING; confirmed (sellable) stays 0.
      expect(
        await ledger.readStoredBalances(seed.stockItemId),
        const LedgerBalances(confirmedPieces: 0, pendingPieces: 30),
      );
      expect(await ledger.reconcile(seed.stockItemId), isTrue);

      // The movement was written as pending (not sellable until synced).
      final movements = await (db.select(db.stockMovements)
            ..where((m) => m.idempotencyKey.equals('recv-reaper-1')))
          .get();
      expect(movements, hasLength(1));
      expect(movements.single.type, MovementType.receive);
      expect(movements.single.syncState, SyncState.pending);
      expect(movements.single.deltaPieces, 30);

      // Exactly one receipt entry and one queued op were written.
      final entries =
          await service.entriesForSession(result.sessionId);
      expect(entries, hasLength(1));
      expect(entries.single.qtyInput, 3);
      expect(entries.single.unit, InputUnit.bunch);
      expect(entries.single.piecesDelta, 30);

      final ops = await db.select(db.pendingOperations).get();
      expect(ops, hasLength(1));
      expect(ops.single.opType, OpType.receiveEntry);
      expect(ops.single.idempotencyKey, 'recv-reaper-1');
      expect(ops.single.syncState, SyncState.pending);
    });

    test('plank input is recorded in pieces (no bunch multiplier)', () async {
      final seed = await _seedPlank(db);

      final result = await service.recordReceivingEntry(
        stockItemId: seed.stockItemId,
        crossSection: seed.crossSection,
        qtyInput: 7,
        unit: InputUnit.piece,
        idempotencyKey: 'recv-plank-1',
      );

      expect(result.piecesDelta, 7);
      expect(
        await ledger.readStoredBalances(seed.stockItemId),
        const LedgerBalances(confirmedPieces: 0, pendingPieces: 7),
      );
    });

    test('start then resume returns the SAME active session (5.1)', () async {
      final first = await service.startOrResumeSession();
      final second = await service.startOrResumeSession();
      expect(second.id, first.id);

      // Recording an entry resumes the same active session rather than opening
      // a new one.
      final seed = await _seedReaper(db);
      final result = await service.recordReceivingEntry(
        stockItemId: seed.stockItemId,
        crossSection: seed.crossSection,
        qtyInput: 1,
        unit: InputUnit.bunch,
        idempotencyKey: 'recv-resume-1',
      );
      expect(result.sessionId, first.id);

      // Only one session row exists.
      final sessions = await db.select(db.receiptSessions).get();
      expect(sessions, hasLength(1));
    });

    test('finishing the session does NOT double-add stock (Req 21.6)',
        () async {
      final seed = await _seedReaper(db);

      await service.recordReceivingEntry(
        stockItemId: seed.stockItemId,
        crossSection: seed.crossSection,
        qtyInput: 3,
        unit: InputUnit.bunch,
        idempotencyKey: 'recv-finish-1',
      );

      final before = await ledger.readStoredBalances(seed.stockItemId);
      expect(before, const LedgerBalances(confirmedPieces: 0, pendingPieces: 30));

      final finished = await service.finishActiveSession();
      expect(finished, isNotNull);
      expect(finished!.status, ReceiptStatus.finished);
      expect(finished.finishedAt, isNotNull);

      // Finishing changed no balances: stock is not re-applied.
      expect(
        await ledger.readStoredBalances(seed.stockItemId),
        before,
      );

      // No active session remains, and finishing again is a harmless no-op.
      expect(await service.activeSession(), isNull);
      final again = await service.finishActiveSession();
      expect(again, isNull);
      expect(
        await ledger.readStoredBalances(seed.stockItemId),
        before,
      );
      // Still exactly one movement row.
      final movements = await db.select(db.stockMovements).get();
      expect(movements, hasLength(1));
    });

    test('repeating the same idempotency key is a no-op (no double add; '
        '5.8, 5.9)', () async {
      final seed = await _seedReaper(db);

      final first = await service.recordReceivingEntry(
        stockItemId: seed.stockItemId,
        crossSection: seed.crossSection,
        qtyInput: 3,
        unit: InputUnit.bunch,
        idempotencyKey: 'dup-key',
      );
      final second = await service.recordReceivingEntry(
        stockItemId: seed.stockItemId,
        crossSection: seed.crossSection,
        qtyInput: 3,
        unit: InputUnit.bunch,
        idempotencyKey: 'dup-key',
      );

      expect(first.outcome, ReceivingOutcome.recorded);
      expect(second.outcome, ReceivingOutcome.duplicateIgnored);

      // Stock added exactly once (still 30 pending, 0 confirmed).
      expect(
        await ledger.readStoredBalances(seed.stockItemId),
        const LedgerBalances(confirmedPieces: 0, pendingPieces: 30),
      );

      // Exactly one entry, one movement, one queued op survive.
      expect(await service.entriesForSession(first.sessionId), hasLength(1));
      final movements = await db.select(db.stockMovements).get();
      expect(movements, hasLength(1));
      final ops = await db.select(db.pendingOperations).get();
      expect(ops, hasLength(1));
    });

    test('pending receive is confirmed by StockLedgerDao into the sellable '
        'balance (pending -> confirmed)', () async {
      final seed = await _seedReaper(db);

      await service.recordReceivingEntry(
        stockItemId: seed.stockItemId,
        crossSection: seed.crossSection,
        qtyInput: 3,
        unit: InputUnit.bunch,
        idempotencyKey: 'recv-confirm-1',
      );

      // Still not sellable while pending.
      expect(
        (await ledger.readStoredBalances(seed.stockItemId)).confirmedPieces,
        0,
      );

      await ledger.confirmMovement('recv-confirm-1');

      // After sync-confirmation the stock becomes confirmed/sellable.
      expect(
        await ledger.readStoredBalances(seed.stockItemId),
        const LedgerBalances(confirmedPieces: 30, pendingPieces: 0),
      );
    });

    test('bunch input for a non-reaper cross-section is rejected', () async {
      final seed = await _seedPlank(db);
      await expectLater(
        service.recordReceivingEntry(
          stockItemId: seed.stockItemId,
          crossSection: seed.crossSection,
          qtyInput: 1,
          unit: InputUnit.bunch,
          idempotencyKey: 'bad-unit',
        ),
        throwsA(isA<ArgumentError>()),
      );
      // No writes happened.
      expect(await db.select(db.stockMovements).get(), isEmpty);
      expect(await db.select(db.receiptEntries).get(), isEmpty);
    });

    test('non-positive quantity is rejected before any write', () async {
      final seed = await _seedReaper(db);
      await expectLater(
        service.recordReceivingEntry(
          stockItemId: seed.stockItemId,
          crossSection: seed.crossSection,
          qtyInput: 0,
          unit: InputUnit.bunch,
          idempotencyKey: 'zero-qty',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(await db.select(db.stockMovements).get(), isEmpty);
    });
  });
}
