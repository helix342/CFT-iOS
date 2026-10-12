/// Unit tests for finalize as a single authenticated hosted transaction
/// (task 11.1).
///
/// These are pure-Dart / headless tests (no device, no network) that verify the
/// design's finalize boundary (design.md -> Transaction Boundaries & Sync ->
/// (d) Finalize sale) against the in-memory `FakeHostedDatabase`:
///
///   * a successful finalize is **atomic** — it deducts stock AND creates the
///     invoice together, allocating the invoice number inside the transaction
///     (Requirements 12.2, 12.4);
///   * a stock-validation failure **aborts with NO partial deduction and NO
///     invoice**, leaving the pre-finalization state exactly as it was
///     (Requirements 12.6, 21.15, 21.20);
///   * finalize **requires an authenticated session** — with none the order
///     stays a draft and nothing is written (Requirements 12.2, 12.3b, 19.3).
///
/// IMPORTANT: the atomicity asserted here is the in-memory `FakeHostedDatabase`
/// transaction semantics (all-or-nothing commit, session-gated access). A real
/// Supabase/Neon-backed `HostedDatabase` is deferred; its production
/// transactional guarantee is validated later (task 17 integration), NOT here.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/allocation_service.dart';
import 'package:wood_cft/application/auth_service.dart';
import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/application/finalize_service.dart';
import 'package:wood_cft/data/hosted_database.dart';
import 'package:wood_cft/domain/catalog.dart';

void main() {
  const calc = CalculationService();

  // A reaper 2×1 cross-section (bunch of 10 pieces).
  final reaper2x1 = CrossSection(
    id: 1,
    widthIn: 2,
    thicknessIn: 1,
    category: WoodCategory.reaper,
  );

  // One sold line: 30 pieces (3 bunches) of the 2×1 reaper at 6 ft, drawn from
  // stock item 100. Its exact CFT comes from the shared engine so money and
  // volume match every other surface.
  AllocationLine soldLine({int pieces = 30}) => AllocationLine(
        stockItemId: 100,
        crossSectionId: reaper2x1.id,
        varietyId: 7,
        lengthFt: 6,
        unit: AllocationUnit.bunch,
        allocatedUnits: pieces ~/ reaper2x1.bunchSize,
        allocatedPieces: pieces,
        allocatedCft: calc.lineCftFor(reaper2x1, 6, pieces),
        isPartial: false,
        shortageUnits: 0,
        shortagePieces: 0,
      );

  OrderAllocation oneLineOrder({int pieces = 30}) {
    final line = soldLine(pieces: pieces);
    return OrderAllocation(
      lineResults: const [],
      lines: [line],
      isPartial: false,
    );
  }

  final snapshots = <int, LineSnapshotInput>{
    100: LineSnapshotInput(
      stockItemId: 100,
      varietyId: 7,
      varietyName: 'Mahogany',
      label: '2 x 1 in, 6 ft',
      rate: Rational.fromInt(1200),
    ),
  };

  group('finalize is a single authenticated hosted transaction (task 11.1)', () {
    test('successful atomic finalize deducts stock AND creates the invoice',
        () async {
      final auth = FakeAuthService(initialSession: const AuthSession(userId: 'owner'));
      final hosted = FakeHostedDatabase(authService: auth);
      final service = FinalizeService(hostedDatabase: hosted, authService: auth);
      final numbers = InMemoryInvoiceNumberAllocator(start: 1);

      // Mirror the Sale deduction into a local map inside the same transaction.
      final deducted = <int, int>{};

      final invoice = await service.finalizeSale(
        allocation: oneLineOrder(),
        snapshots: snapshots,
        confirmedStock: [ConfirmedStock(stockItemId: 100, confirmedPieces: 50)],
        taxMode: TaxMode.eighteen,
        numberAllocator: numbers,
        idempotencyKey: 'finalize-1',
        onDeductStock: (stockItemId, delta) {
          deducted[stockItemId] = (deducted[stockItemId] ?? 0) + delta;
        },
      );

      // Invoice created with the number allocated inside the transaction.
      expect(invoice.number, 1);
      expect(invoice.ownerId, 'owner');
      expect(invoice.lines, hasLength(1));

      // Immutable line snapshot captured variety name/label/rate.
      final snap = invoice.lines.single;
      expect(snap.varietyName, 'Mahogany');
      expect(snap.label, '2 x 1 in, 6 ft');
      expect(snap.rate, Rational.fromInt(1200));
      expect(snap.pieces, 30);

      // Stock deducted by exactly the sold pieces (one signed Sale movement).
      expect(deducted[100], -30);

      // The hosted store committed the invoice effect under the finalize key
      // AND the per-line Sale movement — together (atomic commit).
      expect(hosted.hasApplied('finalize-1'), isTrue);
      expect(hosted.hasApplied('finalize-1:sale:100:6'), isTrue);

      await auth.dispose();
    });

    test(
        'stock-validation failure aborts with NO partial deduction and NO '
        'invoice', () async {
      final auth = FakeAuthService(initialSession: const AuthSession(userId: 'owner'));
      final hosted = FakeHostedDatabase(authService: auth);
      final service = FinalizeService(hostedDatabase: hosted, authService: auth);
      final numbers = InMemoryInvoiceNumberAllocator(start: 1);

      final deducted = <int, int>{};

      // Demand 30 pieces but only 20 are confirmed-available -> must block.
      await expectLater(
        service.finalizeSale(
          allocation: oneLineOrder(pieces: 30),
          snapshots: snapshots,
          confirmedStock: [ConfirmedStock(stockItemId: 100, confirmedPieces: 20)],
          taxMode: TaxMode.eighteen,
          numberAllocator: numbers,
          idempotencyKey: 'finalize-blocked',
          onDeductStock: (stockItemId, delta) {
            deducted[stockItemId] = (deducted[stockItemId] ?? 0) + delta;
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

      // All-or-nothing: nothing committed, no number consumed, no deduction.
      expect(hosted.appliedCount, 0);
      expect(hosted.hasApplied('finalize-blocked'), isFalse);
      expect(deducted, isEmpty);
      expect(numbers.peek, 1, reason: 'a blocked finalize consumes no number');

      await auth.dispose();
    });

    test('missing rate blocks finalize before any write', () async {
      final auth = FakeAuthService(initialSession: const AuthSession(userId: 'owner'));
      final hosted = FakeHostedDatabase(authService: auth);
      final service = FinalizeService(hostedDatabase: hosted, authService: auth);

      await expectLater(
        service.finalizeSale(
          allocation: oneLineOrder(),
          // No snapshot for stock item 100 -> no rate -> blocked.
          snapshots: const <int, LineSnapshotInput>{},
          confirmedStock: [ConfirmedStock(stockItemId: 100, confirmedPieces: 50)],
          taxMode: TaxMode.eighteen,
          numberAllocator: InMemoryInvoiceNumberAllocator(),
          idempotencyKey: 'finalize-no-rate',
        ),
        throwsA(isA<FinalizeBlockedException>()),
      );
      expect(hosted.appliedCount, 0);

      await auth.dispose();
    });

    test('finalize requires an authenticated session (offline keeps a draft)',
        () async {
      final auth = FakeAuthService(); // signed out
      final hosted = FakeHostedDatabase(authService: auth);
      final service = FinalizeService(hostedDatabase: hosted, authService: auth);

      final deducted = <int, int>{};

      await expectLater(
        service.finalizeSale(
          allocation: oneLineOrder(),
          snapshots: snapshots,
          confirmedStock: [ConfirmedStock(stockItemId: 100, confirmedPieces: 50)],
          taxMode: TaxMode.eighteen,
          numberAllocator: InMemoryInvoiceNumberAllocator(),
          idempotencyKey: 'finalize-no-session',
          onDeductStock: (stockItemId, delta) {
            deducted[stockItemId] = (deducted[stockItemId] ?? 0) + delta;
          },
        ),
        throwsA(isA<NotAuthenticatedException>()),
      );

      // No session -> nothing written, order stays a draft.
      expect(hosted.appliedCount, 0);
      expect(deducted, isEmpty);

      await auth.dispose();
    });
  });

  group('finalize is idempotent exactly-once under retry (task 11.2)', () {
    // Verifies Req 12.3 / 12.3a and acceptance examples 21.7 & 21.26: a repeated
    // finalize with the SAME idempotency key (e.g. a retry after a lost or
    // timed-out response) yields EXACTLY ONE invoice and EXACTLY ONE stock
    // deduction — no duplicate invoice, no double deduction, same invoice
    // number — while a DIFFERENT key produces a new invoice.
    //
    // IMPORTANT: asserted against the in-memory `FakeHostedDatabase` (whose
    // keyed `apply`/`stage` collapse a duplicate key to a single effect). The
    // production exactly-once guarantee against a live Supabase/Neon instance
    // is deferred (task 17 integration + the real client wiring), NOT here.

    test(
        'retry with the SAME key -> one invoice, one deduction, same number '
        '(Req 21.7, 21.26)', () async {
      final auth = FakeAuthService(
        initialSession: const AuthSession(userId: 'owner'),
      );
      final hosted = FakeHostedDatabase(authService: auth);
      final service = FinalizeService(hostedDatabase: hosted, authService: auth);
      final numbers = InMemoryInvoiceNumberAllocator(start: 1);

      // Count deductions across BOTH attempts: a retry must not deduct again.
      final deducted = <int, int>{};
      void deduct(int stockItemId, int delta) =>
          deducted[stockItemId] = (deducted[stockItemId] ?? 0) + delta;

      // Same request/inputs on both calls — this is a retry of ONE finalize.
      Future<FinalizedInvoice> finalizeOnce() => service.finalizeSale(
            allocation: oneLineOrder(),
            snapshots: snapshots,
            confirmedStock: [
              ConfirmedStock(stockItemId: 100, confirmedPieces: 50),
            ],
            taxMode: TaxMode.eighteen,
            numberAllocator: numbers,
            idempotencyKey: 'finalize-retry',
            onDeductStock: deduct,
          );

      // First finalize commits exactly one invoice + one deduction.
      final first = await finalizeOnce();
      expect(first.number, 1);
      expect(deducted[100], -30);
      expect(hosted.appliedCount, 2,
          reason: 'invoice op + one sale-movement op committed');

      // The response is "lost" -> the caller retries with the SAME key.
      final retry = await finalizeOnce();

      // Exactly one invoice: same number, same totals, same lines as the first.
      expect(retry.number, first.number, reason: 'no duplicate invoice number');
      expect(retry.lines, hasLength(first.lines.length));
      expect(retry.totals.payable.paise, first.totals.payable.paise);
      expect(retry.idempotencyKey, 'finalize-retry');

      // Exactly one deduction: the retry did NOT re-run onDeductStock.
      expect(deducted[100], -30, reason: 'no double deduction on retry');

      // Exactly one hosted effect per key: the retry staged nothing new.
      expect(hosted.appliedCount, 2,
          reason: 'retry committed no additional hosted effect');
      expect(hosted.hasApplied('finalize-retry'), isTrue);

      // The invoice-number sequence advanced only once across both attempts.
      expect(numbers.peek, 2, reason: 'a retry consumes no new invoice number');

      await auth.dispose();
    });

    test('a DIFFERENT key produces a NEW invoice with the next number',
        () async {
      final auth = FakeAuthService(
        initialSession: const AuthSession(userId: 'owner'),
      );
      final hosted = FakeHostedDatabase(authService: auth);
      final service = FinalizeService(hostedDatabase: hosted, authService: auth);
      final numbers = InMemoryInvoiceNumberAllocator(start: 1);

      final deducted = <int, int>{};
      void deduct(int stockItemId, int delta) =>
          deducted[stockItemId] = (deducted[stockItemId] ?? 0) + delta;

      final first = await service.finalizeSale(
        allocation: oneLineOrder(),
        snapshots: snapshots,
        confirmedStock: [ConfirmedStock(stockItemId: 100, confirmedPieces: 50)],
        taxMode: TaxMode.eighteen,
        numberAllocator: numbers,
        idempotencyKey: 'finalize-a',
        onDeductStock: deduct,
      );

      final second = await service.finalizeSale(
        allocation: oneLineOrder(),
        snapshots: snapshots,
        confirmedStock: [ConfirmedStock(stockItemId: 100, confirmedPieces: 50)],
        taxMode: TaxMode.eighteen,
        numberAllocator: numbers,
        idempotencyKey: 'finalize-b',
        onDeductStock: deduct,
      );

      // A distinct key is a distinct finalize: new number, its own deduction.
      expect(first.number, 1);
      expect(second.number, 2, reason: 'a new key allocates the next number');
      expect(deducted[100], -60, reason: 'two distinct finalizes deduct twice');
      expect(hosted.appliedCount, 4,
          reason: 'two invoice ops + two sale-movement ops');
      expect(hosted.hasApplied('finalize-a'), isTrue);
      expect(hosted.hasApplied('finalize-b'), isTrue);

      await auth.dispose();
    });
  });

  group('void/reversal restores stock exactly once (task 11.3)', () {
    // Verifies design.md -> Transaction Boundaries & Sync -> (e) Void and
    // Requirements 13.1, 13.2, 13.3 (acceptance example 21.23): a void is one
    // authenticated hosted transaction that marks the invoice Voided (the
    // original immutable snapshot is retained, never mutated), inserts positive
    // Void movements restoring exactly the deducted pieces, and restores stock
    // EXACTLY ONCE — under a retried same key AND under a second different key.
    //
    // IMPORTANT: asserted against the in-memory `FakeHostedDatabase` (keyed
    // apply/stage collapse a duplicate key to a single effect). The production
    // transactional + exactly-once guarantee against a live Supabase/Neon
    // instance is deferred (task 17), NOT here.

    // Finalize one invoice (30 pieces from stock item 100) so there is a real
    // deduction to reverse, then return the service + hosted so the void can be
    // exercised against the same store.
    Future<(FinalizeService, FakeHostedDatabase, FinalizedInvoice)>
        finalizeForVoid(FakeAuthService auth) async {
      final hosted = FakeHostedDatabase(authService: auth);
      final service = FinalizeService(hostedDatabase: hosted, authService: auth);
      final invoice = await service.finalizeSale(
        allocation: oneLineOrder(),
        snapshots: snapshots,
        confirmedStock: [ConfirmedStock(stockItemId: 100, confirmedPieces: 50)],
        taxMode: TaxMode.eighteen,
        numberAllocator: InMemoryInvoiceNumberAllocator(start: 1),
        idempotencyKey: 'finalize-for-void',
      );
      return (service, hosted, invoice);
    }

    test('successful void restores the deducted pieces and marks it voided',
        () async {
      final auth =
          FakeAuthService(initialSession: const AuthSession(userId: 'owner'));
      final (service, hosted, invoice) = await finalizeForVoid(auth);

      // Mirror the Void restore into a local map inside the same transaction.
      final restored = <int, int>{};

      final voided = await service.voidSale(
        invoice: invoice,
        idempotencyKey: 'void-1',
        onRestoreStock: (stockItemId, delta) {
          restored[stockItemId] = (restored[stockItemId] ?? 0) + delta;
        },
      );

      // The reversal references the SAME invoice number (not re-allocated).
      expect(voided.number, invoice.number);
      expect(voided.ownerId, 'owner');

      // Stock restored by exactly the sold pieces (+30, the reverse of -30).
      expect(restored[100], 30);
      expect(voided.restoredPieces[100], 30);

      // The invoice is marked voided AND the Void movement committed together.
      expect(hosted.hasApplied('void-1'), isTrue);
      expect(hosted.hasApplied('invoice-voided:${invoice.number}'), isTrue);
      expect(
        hosted.hasApplied('invoice-void-movement:${invoice.number}:100'),
        isTrue,
      );

      // The original immutable snapshot is retained and NOT mutated: its lines
      // and deducted pieces are unchanged by the void (Req 13.2).
      expect(invoice.lines.single.pieces, 30);
      expect(invoice.lines.single.varietyName, 'Mahogany');

      await auth.dispose();
    });

    test('void requires an authenticated session', () async {
      // Finalize while signed in so there is an invoice to void...
      final auth =
          FakeAuthService(initialSession: const AuthSession(userId: 'owner'));
      final (service, hosted, invoice) = await finalizeForVoid(auth);
      final appliedBefore = hosted.appliedCount;

      // ...then sign out: the void must be refused and write nothing.
      await auth.signOut();

      final restored = <int, int>{};
      await expectLater(
        service.voidSale(
          invoice: invoice,
          idempotencyKey: 'void-no-session',
          onRestoreStock: (stockItemId, delta) =>
              restored[stockItemId] = (restored[stockItemId] ?? 0) + delta,
        ),
        throwsA(isA<NotAuthenticatedException>()),
      );

      // No session -> nothing restored, nothing newly committed.
      expect(restored, isEmpty);
      expect(hosted.appliedCount, appliedBefore);
      expect(hosted.hasApplied('invoice-voided:${invoice.number}'), isFalse);

      await auth.dispose();
    });

    test('retry with the SAME void key restores stock exactly once (Req 21.23)',
        () async {
      final auth =
          FakeAuthService(initialSession: const AuthSession(userId: 'owner'));
      final (service, hosted, invoice) = await finalizeForVoid(auth);
      final appliedAfterFinalize = hosted.appliedCount;

      // Count restores across BOTH void attempts: a retry must not restore
      // again.
      final restored = <int, int>{};
      void restore(int stockItemId, int delta) =>
          restored[stockItemId] = (restored[stockItemId] ?? 0) + delta;

      Future<VoidedInvoice> voidOnce() => service.voidSale(
            invoice: invoice,
            idempotencyKey: 'void-retry',
            onRestoreStock: restore,
          );

      // First void restores exactly once.
      final first = await voidOnce();
      expect(restored[100], 30);
      final appliedAfterVoid = hosted.appliedCount;
      expect(appliedAfterVoid, greaterThan(appliedAfterFinalize));

      // The response is "lost" -> the caller retries with the SAME key.
      final retry = await voidOnce();

      // Same reversal, and stock restored EXACTLY ONCE (not +60).
      expect(retry.number, first.number);
      expect(restored[100], 30, reason: 'no double restore on retry');

      // The retry staged no additional hosted effect.
      expect(hosted.appliedCount, appliedAfterVoid,
          reason: 'retry committed no additional hosted effect');

      await auth.dispose();
    });

    test(
        'voiding the same invoice again with a DIFFERENT key cannot '
        'double-restore', () async {
      final auth =
          FakeAuthService(initialSession: const AuthSession(userId: 'owner'));
      final (service, hosted, invoice) = await finalizeForVoid(auth);

      final restored = <int, int>{};
      void restore(int stockItemId, int delta) =>
          restored[stockItemId] = (restored[stockItemId] ?? 0) + delta;

      // First void under key A restores +30.
      await service.voidSale(
        invoice: invoice,
        idempotencyKey: 'void-key-A',
        onRestoreStock: restore,
      );
      expect(restored[100], 30);
      final appliedAfterFirstVoid = hosted.appliedCount;

      // A SECOND void of the SAME invoice under a DIFFERENT key must NOT
      // restore again — the invoice is already voided (Req 13.2, 13.3, 21.23).
      final second = await service.voidSale(
        invoice: invoice,
        idempotencyKey: 'void-key-B',
        onRestoreStock: restore,
      );

      expect(second.number, invoice.number);
      expect(restored[100], 30,
          reason: 'a different-key second void cannot double-restore');

      // No new hosted effect was committed by the second void.
      expect(hosted.appliedCount, appliedAfterFirstVoid,
          reason: 'the second void staged nothing new');
      expect(hosted.hasApplied('void-key-B'), isFalse);

      await auth.dispose();
    });
  });
}
