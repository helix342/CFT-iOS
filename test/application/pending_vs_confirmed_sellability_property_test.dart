// Property-based test for pending-vs-confirmed sellability (task 4.5 /
// Property 21).
//
// Property 21 - Only confirmed stock is sellable (design.md -> Correctness
// Properties; Requirements 5.6, 19.8, 21.27):
//
//   For all mixes of pending (unconfirmed) and confirmed stock movements, the
//   sellable (confirmed) availability used by allocation and finalize equals
//   the signed sum of CONFIRMED movements only; pending received quantity is
//   excluded until synchronization confirms it.
//
// This test exercises the real seam the rest of the app sells against: the
// local movement ledger (`StockLedgerDao`), the durable pending-op queue
// (`PendingOperationQueue`), the sync engine (`SyncService`) that promotes
// pending -> confirmed, and the headless inventory/availability engine
// (`InventoryQueryService`) that reports the sellable quantity used by the
// browser, allocation, and billing.
//
// For each generated scenario we build, per stock item, a random mix of:
//   * CONFIRMED movements — a seeded confirmed opening balance (always
//     non-negative so the ledger's negative-availability guard never fires),
//     and
//   * PENDING receiving movements — one-or-more pending receives recorded
//     locally and enqueued (not yet synced), each inbound (> 0).
//
// The property asserts, BEFORE any sync:
//   * sellable availability (InventoryQueryService.availablePieces /
//     availableCft, and the filtered totals) equals the CONFIRMED balance only;
//   * the pending receiving quantity is reported separately but NEVER counted
//     as available/sellable;
//   * this equals the signed sum of CONFIRMED movements straight from the
//     ledger (reconciliation).
//
// Then it drains the queue (SyncService) with an authenticated session so the
// pending receives are confirmed exactly once, and asserts AFTER sync:
//   * every previously-pending piece is now confirmed and sellable;
//   * the pending reported quantity is zero;
//   * sellable availability now equals confirmed(before) + pending(before),
//     i.e. the pending stock became sellable only once sync confirmed it.
//
// PBT framework: `package:glados` (re-exports `package:test`), matching the
// existing data/application property tests. `ExploreConfig(numRuns: ...)` fixes
// the iteration count (150-200 per task 4.5) and seeds a deterministic
// `Random`, so a failure reproduces exactly.
//
// Pure / headless: boots an in-memory drift `AppDatabase` plus the
// `FakeHostedDatabase` / `FakeAuthService` doubles. No Flutter widgets, no real
// network — runs under `flutter test` on Windows.

import 'package:glados/glados.dart';

import 'package:wood_cft/application/auth_service.dart';
import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/application/inventory_query_service.dart';
import 'package:wood_cft/application/sync_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/hosted_database.dart';
import 'package:wood_cft/data/pending_operation_queue.dart';
import 'package:wood_cft/data/stock_ledger_dao.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/cft.dart';

/// Deterministic exploration config giving the property 175 iterations
/// (150-200 range per task 4.5) from a fixed seed, so any failure reproduces.
final ExploreConfig _explore =
    ExploreConfig(numRuns: 175, random: Random(20240405));

/// A no-sleep [Clock] for the sync engine so backoff never really waits.
Future<void> _instantClock(Duration _) async {}

/// Per-stock-item plan: a confirmed opening balance and a list of pending
/// receive quantities (each > 0) still awaiting sync.
class _ItemPlan {
  const _ItemPlan({required this.confirmedOpening, required this.pendingReceives});

  /// A non-negative confirmed opening balance (always >= 0 so the ledger's
  /// negative-availability guard never fires).
  final int confirmedOpening;

  /// Zero or more pending receive quantities (each >= 1).
  final List<int> pendingReceives;

  /// The total pending (unconfirmed, inbound) pieces for this item.
  int get pendingTotal => pendingReceives.fold(0, (a, b) => a + b);

  @override
  String toString() =>
      '_ItemPlan(confirmed: $confirmedOpening, pending: $pendingReceives)';
}

/// A full scenario: a plan per stock item (one plan => one stock item).
class _Scenario {
  const _Scenario(this.items);
  final List<_ItemPlan> items;

  @override
  String toString() => '_Scenario(${items.length} items: $items)';
}

/// Confirmed opening balance in 0..200 pieces (0 is allowed: confirmed-empty).
final Generator<int> _confirmedOpening = any.intInRange(0, 201);

/// A single pending receive quantity in 1..100 pieces (always inbound).
final Generator<int> _pendingPieces = any.intInRange(1, 101);

/// 0..4 pending receives for one item (so some items are pending-only, some
/// confirmed-only, some mixed, and some entirely empty).
final Generator<List<int>> _pendingReceives =
    any.listWithLengthInRange(0, 5, _pendingPieces);

/// One item plan.
final Generator<_ItemPlan> _itemPlan = any.combine2(
  _confirmedOpening,
  _pendingReceives,
  (int confirmed, List<int> pending) =>
      _ItemPlan(confirmedOpening: confirmed, pendingReceives: pending),
);

/// 1..6 stock items per scenario, each with its own confirmed/pending mix.
final Generator<_Scenario> _scenario =
    any.listWithLengthInRange(1, 7, _itemPlan).map(_Scenario.new);

/// Seeds one shared variety + reaper cross-section and returns their ids. The
/// 2x1 reaper matches the seeded catalog so the CFT values are the real ones.
Future<({int varietyId, int crossSectionId})> _seedCatalog(
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
  return (varietyId: varietyId, crossSectionId: crossSectionId);
}

void main() {
  Glados<_Scenario>(_scenario, _explore).test(
    'Feature: wood-cft-app, Property 21: Only confirmed stock is sellable - '
    'across random mixes of pending and confirmed stock movements, sellable '
    '(confirmed) availability equals the signed sum of confirmed movements '
    'only; pending receiving stock is excluded until sync confirms it, after '
    'which it becomes sellable (Requirements 5.6, 19.8, 21.27)',
    (_Scenario s) async {
      final db = openInMemoryDatabase();
      final auth =
          FakeAuthService(initialSession: const AuthSession(userId: 'owner'));
      final ledger = StockLedgerDao(db);
      final queue = PendingOperationQueue(db);
      final inventory = InventoryQueryService(db, const CalculationService());
      const calc = CalculationService();

      try {
        final catalog = await _seedCatalog(db);
        // Each item uses a distinct length 2..9 ft so they are distinct stock
        // rows (unique variety+cross-section+length) and have distinct CFT.
        final stockItemIds = <int>[];
        final lengths = <int>[];
        final expectedConfirmed = <int, int>{};
        final expectedPending = <int, int>{};

        var keyCounter = 0;

        for (var i = 0; i < s.items.length; i++) {
          final plan = s.items[i];
          final lengthFt = 2 + (i % 8); // 2..9, within the catalog range
          final stockItemId = await db.into(db.stockItems).insert(
                StockItemsCompanion.insert(
                  varietyId: catalog.varietyId,
                  crossSectionId: catalog.crossSectionId,
                  lengthFt: lengthFt,
                ),
              );
          stockItemIds.add(stockItemId);
          lengths.add(lengthFt);

          // CONFIRMED opening balance: a single confirmed OPENING movement.
          if (plan.confirmedOpening > 0) {
            final outcome = await ledger.recordMovement(
              stockItemId: stockItemId,
              type: MovementType.opening,
              deltaPieces: plan.confirmedOpening,
              idempotencyKey: 'confirmed-open-$i',
              syncState: SyncState.confirmed,
            );
            expect(outcome, MovementOutcome.applied);
          }

          // PENDING receives: recorded locally (pending) and enqueued, exactly
          // like the receiving flow (task 5.1) before a sync.
          for (final pieces in plan.pendingReceives) {
            final key = 'pending-recv-$i-${keyCounter++}';
            await db.transaction(() async {
              await ledger.recordMovement(
                stockItemId: stockItemId,
                type: MovementType.receive,
                deltaPieces: pieces,
                idempotencyKey: key,
                syncState: SyncState.pending,
              );
              await queue.enqueue(
                opType: OpType.receiveEntry,
                payload: '{"kind":"receive","pieces":$pieces}',
                idempotencyKey: key,
                enqueuedAt: DateTime.utc(2024, 1, 1).add(Duration(seconds: keyCounter)),
                executor: db,
              );
            });
          }

          expectedConfirmed[stockItemId] = plan.confirmedOpening;
          expectedPending[stockItemId] = plan.pendingTotal;
        }

        // ---- BEFORE SYNC: sellable == confirmed only; pending excluded. ----
        final before = await inventory.query(const InventoryFilter());
        final rowsById = {for (final r in before.rows) r.stockItemId: r};

        var sumConfirmedBefore = 0;
        var sumPendingBefore = 0;
        final confirmedCfts = <Cft>[];

        for (var i = 0; i < stockItemIds.length; i++) {
          final id = stockItemIds[i];
          final lengthFt = lengths[i];
          final row = rowsById[id]!;

          // Sellable availability is the CONFIRMED balance only.
          expect(
            row.availablePieces,
            expectedConfirmed[id],
            reason: 'sellable pieces must equal confirmed only (item $id)',
          );
          // Pending receiving stock is reported but NOT sellable.
          expect(
            row.pendingPieces,
            expectedPending[id],
            reason: 'pending reported separately (item $id)',
          );

          // Reconciliation: the ledger's confirmed/pending agree.
          final ledgerBalances = await ledger.computeBalancesFromLedger(id);
          expect(ledgerBalances.confirmedPieces, expectedConfirmed[id]);
          expect(ledgerBalances.pendingPieces, expectedPending[id]);

          // Available CFT equals the confirmed-only CFT (never pending).
          final crossSection = CrossSection(
            id: 1,
            widthIn: 2,
            thicknessIn: 1,
            category: WoodCategory.reaper,
            bunchSize: 10,
          );
          final expectedCft = expectedConfirmed[id]! > 0
              ? calc.lineCftFor(crossSection, lengthFt, expectedConfirmed[id]!)
              : Cft.zero;
          expect(row.availableCft, expectedCft);
          confirmedCfts.add(expectedCft);

          sumConfirmedBefore += expectedConfirmed[id]!;
          sumPendingBefore += expectedPending[id]!;
        }

        // Filtered totals are confirmed-only too.
        expect(before.totalAvailablePieces, sumConfirmedBefore);
        expect(before.totalPendingPieces, sumPendingBefore);
        expect(before.totalAvailableCft, calc.totalCft(confirmedCfts));

        // ---- SYNC: drain the queue, promoting pending -> confirmed. ----
        final hosted = FakeHostedDatabase(authService: auth);
        final sync = SyncService(
          hostedDatabase: hosted,
          pendingQueue: queue,
          stockLedger: ledger,
          authService: auth,
          sleepClock: _instantClock,
        );
        final syncResult = await sync.drain();
        // Every enqueued pending op confirmed exactly once (no rejections).
        expect(syncResult.failed, isEmpty);
        expect(syncResult.isFullyDrained, isTrue);

        // ---- AFTER SYNC: previously-pending stock is now sellable. ----
        final after = await inventory.query(const InventoryFilter());
        final afterById = {for (final r in after.rows) r.stockItemId: r};

        var sumSellableAfter = 0;
        final sellableCftsAfter = <Cft>[];

        for (var i = 0; i < stockItemIds.length; i++) {
          final id = stockItemIds[i];
          final lengthFt = lengths[i];
          final row = afterById[id]!;

          final expectedSellable = expectedConfirmed[id]! + expectedPending[id]!;
          // The pending stock became sellable only after sync confirmed it.
          expect(
            row.availablePieces,
            expectedSellable,
            reason: 'after sync, confirmed+pending is sellable (item $id)',
          );
          // Nothing left pending once drained.
          expect(row.pendingPieces, 0);

          final crossSection = CrossSection(
            id: 1,
            widthIn: 2,
            thicknessIn: 1,
            category: WoodCategory.reaper,
            bunchSize: 10,
          );
          final expectedCft = expectedSellable > 0
              ? calc.lineCftFor(crossSection, lengthFt, expectedSellable)
              : Cft.zero;
          expect(row.availableCft, expectedCft);
          sellableCftsAfter.add(expectedCft);

          sumSellableAfter += expectedSellable;
        }

        // After sync the sellable totals equal confirmed(before)+pending(before).
        expect(sumSellableAfter, sumConfirmedBefore + sumPendingBefore);
        expect(after.totalAvailablePieces, sumSellableAfter);
        expect(after.totalPendingPieces, 0);
        expect(after.totalAvailableCft, calc.totalCft(sellableCftsAfter));
      } finally {
        await auth.dispose();
        await db.close();
      }
    },
  );
}
