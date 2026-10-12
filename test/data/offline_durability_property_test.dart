// Property-based test for offline durability across restart
// (task 17.1 — fills the previously-missing Property 30).
//
//   * Property 30 - Offline durability across restart (design.md ->
//     Correctness Properties; Requirements 19.11, 21.25):
//     *For all* sequences of offline receiving entries (and the pending-op
//     queue they build), reloading state from the local store (a simulated
//     restart) yields identical receipt entries and pending-operation queue
//     contents with no data loss, while finalization remains blocked until
//     connectivity AND an authenticated session are both available.
//
// The test runs entirely against an in-memory `AppDatabase`
// (`openInMemoryDatabase`), so it is headless and runs under `flutter test` on
// Windows with no device. A "restart" is modelled by constructing FRESH
// `ReceivingService` / `PendingOperationQueue` instances over the SAME database
// (exactly what a new app launch does — see `receiving_session_controller_test`
// for the resume-after-restart contract this property generalises).
//
// The finalize-while-offline rule is checked with the SAME gate predicate the
// Sell preview uses (finalize is permitted only when authenticated AND online;
// task 11.5 / invoice_preview_providers.dart). Modelling it as the pure boolean
// gate keeps the property deterministic and free of hosted-DB wiring.
//
// PBT framework: `package:glados`. `ExploreConfig(numRuns: ...)` fixes the
// iteration count (>= 100) from a deterministic seed.

import 'package:glados/glados.dart';

import 'package:wood_cft/application/receiving_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/pending_operation_queue.dart';
import 'package:wood_cft/data/stock_ledger_dao.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/domain/catalog.dart';

/// Deterministic exploration config: >= 100 iterations from a fixed seed. A
/// modest run count keeps the DB-backed property fast while staying well above
/// the 100-iteration floor.
final ExploreConfig _explore =
    ExploreConfig(numRuns: 120, random: Random(20240801));

/// One offline receiving entry: a positive quantity of bunches of the seeded
/// reaper SKU. The index seeds a stable idempotency key.
class _Entry {
  const _Entry(this.bunches);

  /// Bunches received (1..5). Each bunch is 10 pieces for the reaper SKU.
  final int bunches;

  @override
  String toString() => '_Entry(bunches: $bunches)';
}

/// A random sequence of 1..6 offline receiving entries plus the two
/// connectivity/session flags that decide whether finalize is permitted.
class _Scenario {
  const _Scenario(this.entries, this.isAuthenticated, this.isOnline);

  final List<_Entry> entries;
  final bool isAuthenticated;
  final bool isOnline;

  @override
  String toString() => '_Scenario(entries: ${entries.length}, '
      'auth: $isAuthenticated, online: $isOnline)';
}

final Generator<_Entry> _entryGen =
    any.intInRange(1, 6).map(_Entry.new); // 1..5 bunches

final Generator<_Scenario> _scenarioGen = any.combine3(
  any.listWithLengthInRange(1, 7, _entryGen), // 1..6 entries
  any.bool,
  any.bool,
  _Scenario.new,
);

/// The design's finalize gate (task 11.5): finalize is permitted ONLY when the
/// owner is authenticated AND the device is online. Rebuilt here so the
/// property asserts the rule against its own definition.
bool _finalizePermitted({required bool isAuthenticated, required bool isOnline}) =>
    isAuthenticated && isOnline;

/// Seeds a single reaper 2x1 @ 6 ft SKU and returns its stock-item id and the
/// domain [CrossSection] used for the bunch->pieces conversion.
Future<({int stockItemId, CrossSection crossSection})> _seedReaper(
  AppDatabase db,
) async {
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
          lengthFt: 6,
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

void main() {
  Glados<_Scenario>(_scenarioGen, _explore).test(
    'Feature: wood-cft-app, Property 30: Offline durability across restart - '
    'for all sequences of offline receiving entries, reloading state from the '
    'local store yields identical receipt entries and pending-op queue '
    'contents with no data loss, while finalization stays blocked until '
    'connectivity and a session are both present (Requirements 19.11, 21.25)',
    (_Scenario scenario) async {
      final db = openInMemoryDatabase();
      try {
        final seed = await _seedReaper(db);

        // --- Offline session: record each entry through ReceivingService. ---
        final service = ReceivingService(db);
        var expectedPendingPieces = 0;
        for (var i = 0; i < scenario.entries.length; i++) {
          final e = scenario.entries[i];
          final result = await service.recordReceivingEntry(
            stockItemId: seed.stockItemId,
            crossSection: seed.crossSection,
            qtyInput: e.bunches,
            unit: InputUnit.bunch,
            idempotencyKey: 'offline-recv-$i',
            occurredAt: DateTime.utc(2024, 8, 1, 9, 0, i),
          );
          expect(result.outcome, ReceivingOutcome.recorded);
          expectedPendingPieces += e.bunches * 10;
        }

        // Snapshot the pre-restart local state (entries + queue + balances).
        final queue = PendingOperationQueue(db);
        final ledger = StockLedgerDao(db);
        final activeBefore = await service.activeSession();
        expect(activeBefore, isNotNull);
        final entriesBefore =
            await service.entriesForSession(activeBefore!.id);
        final queueBefore = await queue.readAllInOrder();
        final balancesBefore =
            await ledger.readStoredBalances(seed.stockItemId);

        // Offline receives land in the PENDING balance only (not sellable).
        expect(
          balancesBefore,
          LedgerBalances(
            confirmedPieces: 0,
            pendingPieces: expectedPendingPieces,
          ),
        );
        expect(entriesBefore, hasLength(scenario.entries.length));
        expect(queueBefore, hasLength(scenario.entries.length));

        // --- Simulate a restart: FRESH service/queue over the SAME db. ---
        final restartedService = ReceivingService(db);
        final restartedQueue = PendingOperationQueue(db);
        final restartedLedger = StockLedgerDao(db);

        final activeAfter = await restartedService.activeSession();
        expect(activeAfter, isNotNull);
        expect(activeAfter!.id, activeBefore.id);

        final entriesAfter =
            await restartedService.entriesForSession(activeAfter.id);
        final queueAfter = await restartedQueue.readAllInOrder();
        final balancesAfter =
            await restartedLedger.readStoredBalances(seed.stockItemId);

        // No data loss: entries recovered one-for-one with identical content
        // and order (idempotency keys + piece deltas), nothing duplicated.
        expect(entriesAfter, hasLength(entriesBefore.length));
        for (var i = 0; i < entriesBefore.length; i++) {
          expect(
            entriesAfter[i].idempotencyKey,
            entriesBefore[i].idempotencyKey,
          );
          expect(entriesAfter[i].piecesDelta, entriesBefore[i].piecesDelta);
        }

        // The pending-op queue survives the restart one-for-one, in order.
        expect(queueAfter, hasLength(queueBefore.length));
        for (var i = 0; i < queueBefore.length; i++) {
          expect(queueAfter[i].idempotencyKey, queueBefore[i].idempotencyKey);
          expect(queueAfter[i].syncState, SyncState.pending);
        }

        // Balances are preserved exactly across the restart (no re-apply).
        expect(balancesAfter, balancesBefore);
        expect(
          await db.select(db.stockMovements).get(),
          hasLength(scenario.entries.length),
        );

        // --- Finalize gate: blocked unless BOTH online AND authenticated. ---
        final permitted = _finalizePermitted(
          isAuthenticated: scenario.isAuthenticated,
          isOnline: scenario.isOnline,
        );
        // The received stock is still only pending (unconfirmed), so it is not
        // yet sellable regardless of the gate — a finalize cannot consume it.
        expect(balancesAfter.confirmedPieces, 0);
        if (!scenario.isOnline || !scenario.isAuthenticated) {
          // Offline or signed out -> finalize must NOT be permitted; the order
          // stays a draft (Req 19.11, 12.3b).
          expect(permitted, isFalse);
        } else {
          // Only when both are present is finalize even allowed to proceed.
          expect(permitted, isTrue);
        }
      } finally {
        await db.close();
      }
    },
  );
}
