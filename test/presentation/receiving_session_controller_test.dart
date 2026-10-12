/// Tests for resume-after-restart recovery of the receiving session (task 5.3).
///
/// These boot an in-memory [AppDatabase] (so they run under `flutter test` on
/// Windows with no device), record a receiving entry through
/// [ReceivingService], and then simulate an app restart by disposing the
/// provider container and building a FRESH [ReceivingSessionController] over the
/// SAME database. They assert the recovery contract from design.md
/// (Screen Flows -> Stock tab; Transaction Boundaries & Sync; Req 5.7, 20.6):
///
///   * the active receipt session and its already-committed entries are
///     recovered exactly once after restart;
///   * resuming applies NO stock effects — balances are unchanged by the act of
///     resuming (idempotent recovery, 21.6);
///   * finishing the session after resume does NOT double-add stock.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/application/receiving_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/stock_ledger_dao.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/presentation/settings/business_profile_providers.dart';
import 'package:wood_cft/presentation/stock/receiving_session_controller.dart';

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

/// Builds a provider container bound to [db], as a fresh app launch would.
ProviderContainer _containerOver(AppDatabase db) {
  return ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
  );
}

void main() {
  group('ReceivingSessionController — resume-after-restart recovery', () {
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

    test('with no active session, recovery resolves to the empty state',
        () async {
      final container = _containerOver(db);
      addTearDown(container.dispose);

      final state = await container
          .read(receivingSessionControllerProvider.future);

      expect(state.hasActiveSession, isFalse);
      expect(state.session, isNull);
      expect(state.entries, isEmpty);
    });

    test(
        'restart recovers the active session and its committed entries exactly '
        'once; resuming does not re-apply stock (Req 5.7, 20.6, 21.6)',
        () async {
      final seed = await _seedReaper(db);

      // Pre-restart: an entry is recorded into the (single) active session.
      final recorded = await service.recordReceivingEntry(
        stockItemId: seed.stockItemId,
        crossSection: seed.crossSection,
        qtyInput: 3,
        unit: InputUnit.bunch,
        idempotencyKey: 'recv-restart-1',
      );
      expect(recorded.outcome, ReceivingOutcome.recorded);

      // Balances committed at entry time: 30 pending, 0 confirmed.
      final beforeRestart = await ledger.readStoredBalances(seed.stockItemId);
      expect(
        beforeRestart,
        const LedgerBalances(confirmedPieces: 0, pendingPieces: 30),
      );

      // Simulate an app restart: build a FRESH container (new controller
      // instance) over the SAME database.
      final restarted = _containerOver(db);
      addTearDown(restarted.dispose);

      final state = await restarted
          .read(receivingSessionControllerProvider.future);

      // The active session is recovered...
      expect(state.hasActiveSession, isTrue);
      expect(state.session!.id, recorded.sessionId);
      expect(state.session!.status, ReceiptStatus.active);

      // ...with its committed entry restored exactly once.
      expect(state.entries, hasLength(1));
      expect(state.entries.single.idempotencyKey, 'recv-restart-1');
      expect(state.entries.single.piecesDelta, 30);

      // Resuming re-read state only; balances are unchanged by the resume, and
      // there is still exactly one movement row (no double-apply).
      expect(
        await ledger.readStoredBalances(seed.stockItemId),
        beforeRestart,
      );
      expect(await db.select(db.stockMovements).get(), hasLength(1));
      expect(await db.select(db.receiptEntries).get(), hasLength(1));
    });

    test('finishing after resume does not double-add stock (Req 21.6)',
        () async {
      final seed = await _seedReaper(db);

      await service.recordReceivingEntry(
        stockItemId: seed.stockItemId,
        crossSection: seed.crossSection,
        qtyInput: 3,
        unit: InputUnit.bunch,
        idempotencyKey: 'recv-restart-finish',
      );
      final before = await ledger.readStoredBalances(seed.stockItemId);
      expect(
        before,
        const LedgerBalances(confirmedPieces: 0, pendingPieces: 30),
      );

      // Restart and resume via a fresh controller.
      final restarted = _containerOver(db);
      addTearDown(restarted.dispose);
      final resumed = await restarted
          .read(receivingSessionControllerProvider.future);
      expect(resumed.hasActiveSession, isTrue);

      // Finish the resumed session through the service (fresh instance over the
      // same db, as a new launch would use).
      final finisher = ReceivingService(db);
      final finished = await finisher.finishActiveSession();
      expect(finished, isNotNull);
      expect(finished!.status, ReceiptStatus.finished);

      // Finishing only flipped the status: balances unchanged, exactly one
      // movement survives — stock was added exactly once.
      expect(await ledger.readStoredBalances(seed.stockItemId), before);
      expect(await db.select(db.stockMovements).get(), hasLength(1));
    });

    test('refresh re-reads committed entries without re-applying stock',
        () async {
      final seed = await _seedReaper(db);

      // First launch: no session yet, so recovery is empty.
      final container = _containerOver(db);
      addTearDown(container.dispose);
      final controller =
          container.read(receivingSessionControllerProvider.notifier);
      final initial = await container
          .read(receivingSessionControllerProvider.future);
      expect(initial.hasActiveSession, isFalse);

      // The grid records an entry through the shared service...
      await service.recordReceivingEntry(
        stockItemId: seed.stockItemId,
        crossSection: seed.crossSection,
        qtyInput: 2,
        unit: InputUnit.bunch,
        idempotencyKey: 'recv-refresh-1',
      );
      final afterRecord = await ledger.readStoredBalances(seed.stockItemId);

      // ...and the resumed view refreshes to show it.
      await controller.refresh();
      final refreshed = await container
          .read(receivingSessionControllerProvider.future);
      expect(refreshed.hasActiveSession, isTrue);
      expect(refreshed.entries, hasLength(1));
      expect(refreshed.entries.single.idempotencyKey, 'recv-refresh-1');

      // Refreshing is a pure read: no extra movement, balances unchanged.
      expect(await ledger.readStoredBalances(seed.stockItemId), afterRecord);
      expect(await db.select(db.stockMovements).get(), hasLength(1));
    });
  });
}
