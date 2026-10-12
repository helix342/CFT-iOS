/// Cross-cutting INTEGRATION tests (task 17.3): finalize atomicity, auth/RLS,
/// and sync exactly-once, wired end-to-end across multiple layers.
///
/// Unlike the per-service unit tests (which exercise one service against a
/// hand-built double), these tests wire the real collaborators together over
/// BOTH authoritative seams the design defines:
///
///   * the in-memory [FakeHostedDatabase] (the hosted authoritative store), and
///   * a real in-memory `drift` [AppDatabase] via [StockLedgerDao] +
///     [PendingOperationQueue] (the local cache / movement ledger / durable
///     queue).
///
/// They assert the three cross-layer guarantees from design.md -> Testing
/// Strategy (integration) and -> Transaction Boundaries & Sync:
///
///   (a) **Finalize atomicity (all-or-nothing across BOTH stores).** A finalize
///       whose in-transaction revalidation fails leaves NO invoice in the
///       hosted store AND NO stock change in the local ledger; a successful
///       finalize commits the invoice and the local deduction together
///       (Requirements 12.2, 12.4, 12.6, 21.15, 21.20).
///   (b) **Auth / RLS gate.** Every privileged operation — finalize, void, a
///       sync drain, and a direct hosted read/write — is refused with
///       [NotAuthenticatedException] when no owner session exists, and succeeds
///       once signed in (Requirements 12.2, 12.3b, 19.3).
///   (c) **Sync exactly-once.** Draining the durable pending queue applies each
///       op exactly once in the hosted store even under retries / duplicate
///       enqueues and a simulated lost response, and the pending -> confirmed
///       promotion is never double-counted in the local ledger (Requirements
///       19.8, 19.9, 19.10, 21.26).
///
/// IMPORTANT — scope of these guarantees. The atomicity and exactly-once
/// behaviour asserted here are the **semantics of the in-memory
/// `FakeHostedDatabase` mock** (all-or-nothing commit of a throwing body,
/// session-gated access, idempotency-key-keyed apply) composed with the real
/// local drift transactions. A real Supabase/Neon-backed `HostedDatabase` is
/// **deferred** (see `hosted_database.dart` / `hosted_database_providers.dart`):
/// the production RLS enforcement and the production transactional / exactly-
/// once guarantee against a live hosted instance are NOT validated here. These
/// tests pin the contract the real client must later satisfy.
///
/// Headless: pure Dart + an in-memory drift DB, so they run under
/// `flutter test` on Windows with no device and no network.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/allocation_service.dart';
import 'package:wood_cft/application/auth_service.dart';
import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/application/finalize_service.dart';
import 'package:wood_cft/application/sync_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/hosted_database.dart';
import 'package:wood_cft/data/pending_operation_queue.dart';
import 'package:wood_cft/data/stock_ledger_dao.dart';
// `TaxMode` is defined in both billing_service.dart and tables.dart; the
// finalize/billing flow takes the application-layer one, so hide the data-layer
// enum here to disambiguate.
import 'package:wood_cft/data/tables.dart' hide TaxMode;
import 'package:wood_cft/domain/catalog.dart';

// ---------------------------------------------------------------------------
// Shared fixtures.
// ---------------------------------------------------------------------------

const _calc = CalculationService();

/// A reaper 2x1 cross-section (bunch of 10 pieces) used by every sold line.
final _reaper2x1 = CrossSection(
  id: 1,
  widthIn: 2,
  thicknessIn: 1,
  category: WoodCategory.reaper,
);

/// Seeds a variety + cross-section + stock item in the local drift DB and
/// returns the stock item id. Mirrors the receiving/sync test helper so the
/// local ledger used by these integration tests is a real persisted row.
Future<int> _seedStockItem(AppDatabase db, {int lengthFt = 6}) async {
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
  return db.into(db.stockItems).insert(
        StockItemsCompanion.insert(
          varietyId: varietyId,
          crossSectionId: crossSectionId,
          lengthFt: lengthFt,
        ),
      );
}

/// Records one CONFIRMED opening movement so [stockItemId] has sellable stock,
/// then asserts the reconciliation invariant holds. Returns the confirmed
/// balance. Used to prime the local ledger before a finalize deducts from it.
Future<void> _seedConfirmedStock(
  StockLedgerDao ledger, {
  required int stockItemId,
  required int pieces,
}) async {
  await ledger.recordMovement(
    stockItemId: stockItemId,
    type: MovementType.opening,
    deltaPieces: pieces,
    idempotencyKey: 'seed:$stockItemId',
    syncState: SyncState.confirmed,
    occurredAt: DateTime.utc(2024, 1, 1),
  );
}

/// One sold line: [pieces] pieces of the 2x1 reaper at 6 ft from [stockItemId].
AllocationLine _soldLine({required int stockItemId, int pieces = 30}) =>
    AllocationLine(
      stockItemId: stockItemId,
      crossSectionId: _reaper2x1.id,
      varietyId: 7,
      lengthFt: 6,
      unit: AllocationUnit.bunch,
      allocatedUnits: pieces ~/ _reaper2x1.bunchSize,
      allocatedPieces: pieces,
      allocatedCft: _calc.lineCftFor(_reaper2x1, 6, pieces),
      isPartial: false,
      shortageUnits: 0,
      shortagePieces: 0,
    );

OrderAllocation _oneLineOrder({required int stockItemId, int pieces = 30}) =>
    OrderAllocation(
      lineResults: const [],
      lines: [_soldLine(stockItemId: stockItemId, pieces: pieces)],
      isPartial: false,
    );

Map<int, LineSnapshotInput> _snapshots(int stockItemId) =>
    <int, LineSnapshotInput>{
      stockItemId: LineSnapshotInput(
        stockItemId: stockItemId,
        varietyId: 7,
        varietyName: 'Mahogany',
        label: '2 x 1 in, 6 ft',
        rate: Rational.fromInt(1200),
      ),
    };

/// A no-sleep [Clock] for [SyncService] that records requested backoff delays
/// and completes instantly, so retries never really wait.
class _RecordingClock {
  final List<Duration> delays = <Duration>[];
  Future<void> call(Duration delay) async => delays.add(delay);
}

/// How [_FaultyHostedDatabase] should behave on an `apply` call.
enum _FaultMode {
  /// Delegate straight through to the backing fake (apply exactly once).
  none,

  /// Apply to the backing store, THEN throw a transient error — simulates a
  /// lost/timed-out response for a request the server actually applied.
  lostResponse,
}

/// A [HostedDatabase] wrapper that injects a fault on the first N `apply` calls
/// and otherwise delegates to a backing [FakeHostedDatabase]. Used to drive the
/// sync exactly-once test through a simulated lost response.
class _FaultyHostedDatabase implements HostedDatabase {
  _FaultyHostedDatabase(this.inner, {required this.plan});

  final FakeHostedDatabase inner;

  /// One entry per expected [apply] call; calls past the plan behave as
  /// [_FaultMode.none].
  final List<_FaultMode> plan;

  int applyCalls = 0;

  @override
  Future<HostedApplyResult> apply(HostedOperation operation) async {
    final mode = applyCalls < plan.length ? plan[applyCalls] : _FaultMode.none;
    applyCalls += 1;
    switch (mode) {
      case _FaultMode.none:
        return inner.apply(operation);
      case _FaultMode.lostResponse:
        await inner.apply(operation); // server applied it...
        throw TimeoutException('response lost after apply'); // ...client lost it
    }
  }

  @override
  Future<T> runTransaction<T>(
    FutureOr<T> Function(HostedTransaction txn) body,
  ) =>
      inner.runTransaction<T>(body);

  @override
  Future<Map<String, Object?>> readConfirmed(String idempotencyKey) =>
      inner.readConfirmed(idempotencyKey);
}

void main() {
  // =========================================================================
  // (a) FINALIZE ATOMICITY across the hosted store AND the local ledger.
  // =========================================================================
  group('(a) finalize atomicity across hosted store + local ledger', () {
    late AppDatabase db;
    late FakeAuthService auth;
    late StockLedgerDao ledger;
    late FakeHostedDatabase hosted;
    late FinalizeService service;
    late int stockItemId;

    setUp(() async {
      db = openInMemoryDatabase();
      auth = FakeAuthService(initialSession: const AuthSession(userId: 'owner'));
      ledger = StockLedgerDao(db);
      hosted = FakeHostedDatabase(authService: auth);
      service = FinalizeService(hostedDatabase: hosted, authService: auth);
      stockItemId = await _seedStockItem(db);
      // Prime the local ledger with 50 confirmed (sellable) pieces.
      await _seedConfirmedStock(ledger, stockItemId: stockItemId, pieces: 50);
    });

    tearDown(() async {
      await auth.dispose();
      await db.close();
    });

    test(
        'a finalize that fails revalidation leaves NO invoice AND NO stock '
        'change (all-or-nothing across both stores)', () async {
      final numbers = InMemoryInvoiceNumberAllocator(start: 1);
      final before = await ledger.readStoredBalances(stockItemId);
      expect(before.confirmedPieces, 50);

      // Demand 30 but only tell revalidation 20 are confirmed-available: the
      // in-transaction revalidation blocks. The local deduction is mirrored
      // through onDeductStock INSIDE the hosted transaction, so if the body
      // throws neither store may change.
      await expectLater(
        service.finalizeSale(
          allocation: _oneLineOrder(stockItemId: stockItemId, pieces: 30),
          snapshots: _snapshots(stockItemId),
          confirmedStock: [
            ConfirmedStock(stockItemId: stockItemId, confirmedPieces: 20),
          ],
          taxMode: TaxMode.eighteen,
          numberAllocator: numbers,
          idempotencyKey: 'finalize-block',
          onDeductStock: (itemId, delta) async {
            // Would deduct from the local ledger — but the enclosing hosted
            // transaction throws first, so this hook never commits anything.
            await ledger.recordMovement(
              stockItemId: itemId,
              type: MovementType.sale,
              deltaPieces: delta,
              idempotencyKey: 'finalize-block:sale:$itemId',
              syncState: SyncState.confirmed,
            );
          },
        ),
        throwsA(
          isA<FinalizeBlockedException>().having(
            (e) => e.kind,
            'kind',
            FinalizeBlockReason.insufficientStock,
          ),
        ),
      );

      // Hosted store: no invoice effect committed, no number consumed.
      expect(hosted.appliedCount, 0);
      expect(hosted.hasApplied('finalize-block'), isFalse);
      expect(numbers.peek, 1, reason: 'a blocked finalize consumes no number');

      // Local ledger: balance unchanged and the reconciliation invariant holds
      // (no stray Sale movement leaked through the aborted hook).
      final after = await ledger.readStoredBalances(stockItemId);
      expect(after.confirmedPieces, 50, reason: 'no partial local deduction');
      expect(await ledger.reconcile(stockItemId), isTrue);
    });

    test(
        'a successful finalize commits the invoice AND the local deduction '
        'together', () async {
      final numbers = InMemoryInvoiceNumberAllocator(start: 1);

      final invoice = await service.finalizeSale(
        allocation: _oneLineOrder(stockItemId: stockItemId, pieces: 30),
        snapshots: _snapshots(stockItemId),
        confirmedStock: [
          ConfirmedStock(stockItemId: stockItemId, confirmedPieces: 50),
        ],
        taxMode: TaxMode.eighteen,
        numberAllocator: numbers,
        idempotencyKey: 'finalize-ok',
        onDeductStock: (itemId, delta) async {
          await ledger.recordMovement(
            stockItemId: itemId,
            type: MovementType.sale,
            deltaPieces: delta,
            idempotencyKey: 'finalize-ok:sale:$itemId',
            syncState: SyncState.confirmed,
          );
        },
      );

      // Hosted store: invoice + per-line Sale movement committed together.
      expect(invoice.number, 1);
      expect(hosted.hasApplied('finalize-ok'), isTrue);
      expect(hosted.hasApplied('finalize-ok:sale:$stockItemId:6'), isTrue);

      // Local ledger: deducted by exactly the sold pieces (50 - 30 = 20), and
      // the reconciliation invariant still holds.
      final after = await ledger.readStoredBalances(stockItemId);
      expect(after.confirmedPieces, 20, reason: '50 confirmed - 30 sold');
      expect(await ledger.reconcile(stockItemId), isTrue);
    });

    test(
        'a hook failure (local ledger write) aborts the whole finalize — no '
        'hosted invoice is committed', () async {
      // The local negative-availability guard throws INSIDE the hosted
      // transaction body. That throw must roll the whole thing back: no hosted
      // invoice, no number consumed. (Demand 30 pieces against only 10 local
      // confirmed, but tell revalidation 50 are available so the block comes
      // from the LOCAL hook, not hosted revalidation.)
      final db2 = openInMemoryDatabase();
      final ledger2 = StockLedgerDao(db2);
      final item2 = await _seedStockItem(db2);
      await _seedConfirmedStock(ledger2, stockItemId: item2, pieces: 10);
      final hosted2 = FakeHostedDatabase(authService: auth);
      final service2 =
          FinalizeService(hostedDatabase: hosted2, authService: auth);
      final numbers = InMemoryInvoiceNumberAllocator(start: 1);

      await expectLater(
        service2.finalizeSale(
          allocation: _oneLineOrder(stockItemId: item2, pieces: 30),
          snapshots: _snapshots(item2),
          confirmedStock: [
            ConfirmedStock(stockItemId: item2, confirmedPieces: 50),
          ],
          taxMode: TaxMode.eighteen,
          numberAllocator: numbers,
          idempotencyKey: 'finalize-hook-abort',
          onDeductStock: (itemId, delta) async {
            // Local ledger has only 10; deducting 30 drives it negative and the
            // DAO throws, aborting the enclosing hosted transaction.
            await ledger2.recordMovement(
              stockItemId: itemId,
              type: MovementType.sale,
              deltaPieces: delta,
              idempotencyKey: 'finalize-hook-abort:sale:$itemId',
              syncState: SyncState.confirmed,
            );
          },
        ),
        throwsA(isA<NegativeBalanceException>()),
      );

      // Hosted store rolled back entirely; local ledger unchanged. The
      // in-memory number allocator may have advanced its counter before the
      // hook threw, but NO number was committed to the hosted state — a gap
      // from a rolled-back attempt is acceptable by design (Req 12.4). The
      // atomicity guarantee is that nothing is COMMITTED, not that a plain
      // counter is rewound.
      expect(hosted2.appliedCount, 0, reason: 'nothing committed on abort');
      final after = await ledger2.readStoredBalances(item2);
      expect(after.confirmedPieces, 10);
      expect(await ledger2.reconcile(item2), isTrue);

      await db2.close();
    });
  });

  // =========================================================================
  // (b) AUTH / RLS gate: privileged ops refused with no session, allowed with.
  // =========================================================================
  group('(b) auth/RLS gate on every privileged operation', () {
    late AppDatabase db;
    late StockLedgerDao ledger;
    late PendingOperationQueue queue;
    late int stockItemId;

    setUp(() async {
      db = openInMemoryDatabase();
      ledger = StockLedgerDao(db);
      queue = PendingOperationQueue(db);
      stockItemId = await _seedStockItem(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('finalize is refused without a session and succeeds with one',
        () async {
      final signedOut = FakeAuthService(); // no session
      final hostedOut = FakeHostedDatabase(authService: signedOut);
      final serviceOut =
          FinalizeService(hostedDatabase: hostedOut, authService: signedOut);

      await expectLater(
        serviceOut.finalizeSale(
          allocation: _oneLineOrder(stockItemId: stockItemId),
          snapshots: _snapshots(stockItemId),
          confirmedStock: [
            ConfirmedStock(stockItemId: stockItemId, confirmedPieces: 50),
          ],
          taxMode: TaxMode.eighteen,
          numberAllocator: InMemoryInvoiceNumberAllocator(),
          idempotencyKey: 'finalize-nosession',
        ),
        throwsA(isA<NotAuthenticatedException>()),
      );
      expect(hostedOut.appliedCount, 0, reason: 'nothing written when signed out');
      await signedOut.dispose();

      // Now signed in: the same finalize succeeds.
      final signedIn =
          FakeAuthService(initialSession: const AuthSession(userId: 'owner'));
      final hostedIn = FakeHostedDatabase(authService: signedIn);
      final serviceIn =
          FinalizeService(hostedDatabase: hostedIn, authService: signedIn);
      final invoice = await serviceIn.finalizeSale(
        allocation: _oneLineOrder(stockItemId: stockItemId),
        snapshots: _snapshots(stockItemId),
        confirmedStock: [
          ConfirmedStock(stockItemId: stockItemId, confirmedPieces: 50),
        ],
        taxMode: TaxMode.eighteen,
        numberAllocator: InMemoryInvoiceNumberAllocator(start: 1),
        idempotencyKey: 'finalize-session',
      );
      expect(invoice.number, 1);
      expect(hostedIn.hasApplied('finalize-session'), isTrue);
      await signedIn.dispose();
    });

    test('void is refused without a session and succeeds with one', () async {
      // Finalize once while signed in so there is an invoice to void.
      final auth =
          FakeAuthService(initialSession: const AuthSession(userId: 'owner'));
      final hosted = FakeHostedDatabase(authService: auth);
      final service = FinalizeService(hostedDatabase: hosted, authService: auth);
      final invoice = await service.finalizeSale(
        allocation: _oneLineOrder(stockItemId: stockItemId),
        snapshots: _snapshots(stockItemId),
        confirmedStock: [
          ConfirmedStock(stockItemId: stockItemId, confirmedPieces: 50),
        ],
        taxMode: TaxMode.eighteen,
        numberAllocator: InMemoryInvoiceNumberAllocator(start: 1),
        idempotencyKey: 'finalize-for-void',
      );
      final appliedBefore = hosted.appliedCount;

      // Sign out: the void is refused and writes nothing.
      await auth.signOut();
      await expectLater(
        service.voidSale(invoice: invoice, idempotencyKey: 'void-nosession'),
        throwsA(isA<NotAuthenticatedException>()),
      );
      expect(hosted.appliedCount, appliedBefore);
      expect(hosted.hasApplied('invoice-voided:${invoice.number}'), isFalse);

      // Sign back in: the void now succeeds.
      await auth.signIn();
      final voided =
          await service.voidSale(invoice: invoice, idempotencyKey: 'void-ok');
      expect(voided.number, invoice.number);
      expect(hosted.hasApplied('invoice-voided:${invoice.number}'), isTrue);

      await auth.dispose();
    });

    test('sync drain is refused without a session and succeeds with one',
        () async {
      // Enqueue a pending receive + its local movement (keyed the same).
      final enqueuedAt = DateTime.utc(2024, 1, 1, 9);
      await db.transaction(() async {
        await ledger.recordMovement(
          stockItemId: stockItemId,
          type: MovementType.receive,
          deltaPieces: 10,
          idempotencyKey: 'drain-op',
          syncState: SyncState.pending,
          occurredAt: enqueuedAt,
        );
        await queue.enqueue(
          opType: OpType.receiveEntry,
          payload: '{"pieces":10}',
          idempotencyKey: 'drain-op',
          enqueuedAt: enqueuedAt,
          executor: db,
        );
      });

      // Signed out: drain is refused and the op stays pending (nothing lost).
      final signedOut = FakeAuthService();
      final hostedOut = FakeHostedDatabase(authService: signedOut);
      final syncOut = SyncService(
        hostedDatabase: hostedOut,
        pendingQueue: queue,
        stockLedger: ledger,
        authService: signedOut,
      );
      await expectLater(
        syncOut.drain(),
        throwsA(isA<NotAuthenticatedException>()),
      );
      expect(hostedOut.appliedCount, 0);
      final stillPending = await queue.findByIdempotencyKey('drain-op');
      expect(stillPending!.syncState, SyncState.pending);
      await signedOut.dispose();

      // Signed in: the same drain confirms the op and promotes the balance.
      final signedIn =
          FakeAuthService(initialSession: const AuthSession(userId: 'owner'));
      final hostedIn = FakeHostedDatabase(authService: signedIn);
      final syncIn = SyncService(
        hostedDatabase: hostedIn,
        pendingQueue: queue,
        stockLedger: ledger,
        authService: signedIn,
      );
      final result = await syncIn.drain();
      expect(result.confirmed.length, 1);
      expect(hostedIn.hasApplied('drain-op'), isTrue);
      final after = await ledger.readStoredBalances(stockItemId);
      expect(after.confirmedPieces, 10);
      expect(after.pendingPieces, 0);
      await signedIn.dispose();
    });

    test('direct hosted reads/writes are refused without a session', () async {
      final signedOut = FakeAuthService();
      final hosted = FakeHostedDatabase(authService: signedOut);

      await expectLater(
        hosted.apply(
          const HostedOperation(kind: 'x', idempotencyKey: 'k'),
        ),
        throwsA(isA<NotAuthenticatedException>()),
      );
      await expectLater(
        hosted.readConfirmed('k'),
        throwsA(isA<NotAuthenticatedException>()),
      );
      await expectLater(
        hosted.runTransaction((txn) async {}),
        throwsA(isA<NotAuthenticatedException>()),
      );
      expect(hosted.appliedCount, 0);
      await signedOut.dispose();

      // With a session, the same apply/read succeed.
      final signedIn =
          FakeAuthService(initialSession: const AuthSession(userId: 'owner'));
      final hostedIn = FakeHostedDatabase(authService: signedIn);
      final applied = await hostedIn.apply(
        const HostedOperation(kind: 'x', idempotencyKey: 'k'),
      );
      expect(applied.applied, isTrue);
      final confirmed = await hostedIn.readConfirmed('k');
      expect(confirmed, isNotNull);
      await signedIn.dispose();
    });
  });

  // =========================================================================
  // (c) SYNC EXACTLY-ONCE: each op applied once under retries/duplicates, and
  //     pending -> confirmed promotion is never double-counted.
  // =========================================================================
  group('(c) sync drains the pending queue exactly-once', () {
    late AppDatabase db;
    late FakeAuthService auth;
    late StockLedgerDao ledger;
    late PendingOperationQueue queue;
    late int stockItemId;

    setUp(() async {
      db = openInMemoryDatabase();
      auth = FakeAuthService(initialSession: const AuthSession(userId: 'owner'));
      ledger = StockLedgerDao(db);
      queue = PendingOperationQueue(db);
      stockItemId = await _seedStockItem(db);
    });

    tearDown(() async {
      await auth.dispose();
      await db.close();
    });

    /// Enqueue a pending receive + its matching local movement under one key.
    Future<void> enqueueReceive({
      required int pieces,
      required String key,
      required DateTime at,
    }) async {
      await db.transaction(() async {
        await ledger.recordMovement(
          stockItemId: stockItemId,
          type: MovementType.receive,
          deltaPieces: pieces,
          idempotencyKey: key,
          syncState: SyncState.pending,
          occurredAt: at,
        );
        await queue.enqueue(
          opType: OpType.receiveEntry,
          payload: '{"pieces":$pieces}',
          idempotencyKey: key,
          enqueuedAt: at,
          executor: db,
        );
      });
    }

    test(
        'a duplicate enqueue of the same key is drained once; promotion is not '
        'double-counted', () async {
      // Enqueue the SAME key twice (e.g. a double-tap / resumed receipt). The
      // unique idempotency key collapses it to ONE queue row and ONE local
      // movement, so the pending balance reflects 10, not 20.
      final at = DateTime.utc(2024, 1, 1, 9);
      await enqueueReceive(pieces: 10, key: 'dup', at: at);
      await enqueueReceive(pieces: 10, key: 'dup', at: at);

      final rows = await queue.readPendingInOrder();
      expect(rows, hasLength(1), reason: 'duplicate enqueue is a no-op');
      final before = await ledger.readStoredBalances(stockItemId);
      expect(before.pendingPieces, 10, reason: 'local movement not double-added');

      final hosted = FakeHostedDatabase(authService: auth);
      final sync = SyncService(
        hostedDatabase: hosted,
        pendingQueue: queue,
        stockLedger: ledger,
        authService: auth,
      );

      // First drain confirms and promotes exactly 10.
      final r1 = await sync.drain();
      expect(r1.confirmed.length, 1);
      expect(hosted.appliedCount, 1);
      final after1 = await ledger.readStoredBalances(stockItemId);
      expect(after1.confirmedPieces, 10);
      expect(after1.pendingPieces, 0);

      // A SECOND drain is a no-op: the op is already confirmed, nothing is
      // promoted again (no double count).
      final r2 = await sync.drain();
      expect(r2.results, isEmpty, reason: 'no pending ops remain');
      expect(hosted.appliedCount, 1, reason: 'no second hosted effect');
      final after2 = await ledger.readStoredBalances(stockItemId);
      expect(after2.confirmedPieces, 10, reason: 'promotion not double-counted');
    });

    test(
        'a simulated lost response is retried with the same key and applies '
        'exactly once', () async {
      await enqueueReceive(
        pieces: 15,
        key: 'lost',
        at: DateTime.utc(2024, 1, 1, 9),
      );

      final inner = FakeHostedDatabase(authService: auth);
      final hosted = _FaultyHostedDatabase(
        inner,
        // First apply: server applies, response lost. Retry: duplicate no-op.
        plan: <_FaultMode>[_FaultMode.lostResponse],
      );
      final clock = _RecordingClock();
      final sync = SyncService(
        hostedDatabase: hosted,
        pendingQueue: queue,
        stockLedger: ledger,
        authService: auth,
        backoffStrategy: const ExponentialBackoff(
          base: Duration(milliseconds: 5),
          maxAttempts: 5,
        ),
        sleepClock: clock.call,
      );

      final result = await sync.drain();
      final op = result.results.single;

      // Succeeded on the retry; two apply calls but exactly one hosted effect.
      expect(op.status, SyncOpStatus.confirmed);
      expect(op.attempts, 2);
      expect(hosted.applyCalls, 2);
      expect(inner.appliedCount, 1, reason: 'lost-but-applied not duplicated');

      // Local movement promoted exactly once (not +30).
      final after = await ledger.readStoredBalances(stockItemId);
      expect(after.confirmedPieces, 15);
      expect(after.pendingPieces, 0);
      expect(clock.delays, hasLength(1), reason: 'one backoff between attempts');
    });

    test('many distinct ops each drain exactly once, in enqueue order',
        () async {
      await enqueueReceive(pieces: 1, key: 'a', at: DateTime.utc(2024, 1, 1, 9));
      await enqueueReceive(pieces: 2, key: 'b', at: DateTime.utc(2024, 1, 1, 10));
      await enqueueReceive(pieces: 3, key: 'c', at: DateTime.utc(2024, 1, 1, 11));

      final hosted = FakeHostedDatabase(authService: auth);
      final sync = SyncService(
        hostedDatabase: hosted,
        pendingQueue: queue,
        stockLedger: ledger,
        authService: auth,
      );

      final result = await sync.drain();
      expect(
        result.results.map((r) => r.idempotencyKey).toList(),
        <String>['a', 'b', 'c'],
        reason: 'drained in enqueue order',
      );
      expect(hosted.appliedCount, 3);

      // Re-draining applies nothing new; the balance is the one-time sum 1+2+3.
      final again = await sync.drain();
      expect(again.results, isEmpty);
      expect(hosted.appliedCount, 3);
      final after = await ledger.readStoredBalances(stockItemId);
      expect(after.confirmedPieces, 6);
      expect(after.pendingPieces, 0);
    });
  });
}
