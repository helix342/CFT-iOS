/// Finalize a sale as a **single authenticated hosted transaction** (task 11.1).
///
/// `FinalizeService` turns a priced, allocated draft order into a permanent
/// invoice. It implements design.md -> Transaction Boundaries & Sync ->
/// **(d) Finalize sale (all-or-nothing)**: finalize requires an authenticated
/// owner session and runs the whole effect inside ONE
/// `HostedDatabase.runTransaction`, in the design's fixed order:
///
///   1. **Revalidate** `Confirmed_Available_Stock` and that every sold line has
///      a valid (strictly positive) rate (Requirements 4.7, 12.6).
///   2. Write the `Invoice` row and the **immutable `InvoiceLine` snapshots**
///      (variety name/label and rate are snapshotted onto the line so a later
///      catalog/price change can never alter an issued invoice — Requirement
///      12.4; task 11.4).
///   3. **Allocate the permanent invoice number only inside this transaction**
///      (a rolled-back attempt never consumes a number; gaps from rolled-back
///      attempts are acceptable — Requirement 12.4).
///   4. **Deduct stock** via confirmed `Sale` movements and balance updates.
///   5. Record the finalize `idempotency_key`.
///
/// Because the whole body runs inside `runTransaction`, it is **all-or-nothing**
/// (Requirement 12.2, 12.4): if revalidation finds a missing rate or
/// insufficient stock the body throws, so NO invoice is written, NO invoice
/// number is consumed, and NO stock is deducted — the authoritative state is
/// left exactly as before (Requirement 21.15, 21.20). A draft/preview, by
/// contrast, never reaches this service and never mutates stock (Requirement
/// 12.1, 12.5, 21.21).
///
/// Offline / no session: every entry point goes through
/// `HostedDatabase.runTransaction`, which calls `AuthService.requireSession`.
/// With no authenticated session the transaction is refused with
/// `NotAuthenticatedException` and the order simply **stays a draft** — nothing
/// is written (Requirement 12.2, 12.3b, 19.3).
///
/// ## Idempotent exactly-once retry (task 11.2)
///
/// Finalize is protected by the caller-supplied `idempotencyKey` so that a
/// repeated finalize — in particular a retry after an **uncertain outcome**
/// (the response was lost or the request timed out) — yields **exactly one
/// invoice and exactly one stock deduction** (Requirement 12.3, 12.3a, 12.3b;
/// Property 19; Req 21.7, 21.26). Before opening the transaction, finalize
/// reads the authoritative confirmed state for the key
/// (`HostedDatabase.readConfirmed`): if the key was **already applied**, the
/// first finalize already committed, so the retry does NOT allocate a new
/// invoice number, does NOT stage a second invoice/sale effect, and does NOT
/// re-run the `onDeductStock` hook. Instead it **recomputes the equivalent
/// invoice from the same deterministic inputs but reuses the original invoice
/// number** recorded under the key, returning a result identical to the first
/// finalize (same number, same lines, same totals). A fresh key takes the full
/// path and allocates a new number. This is verified against the in-memory
/// `FakeHostedDatabase` (whose `apply`/`stage` already collapse a duplicate key
/// to a single effect); the production guarantee against live Supabase/Neon is
/// deferred (see below).
///
/// ## Verified against the in-memory fake, not real Supabase/Neon (deferred)
///
/// A real Supabase/Neon-backed `HostedDatabase` is **deferred** (see
/// `hosted_database.dart` / `hosted_database_providers.dart`). This service is
/// therefore written against the pure `HostedDatabase` **interface** and is
/// verified in tests against the in-memory `FakeHostedDatabase`, which models
/// the authoritative store's two guarantees this flow relies on: privileged
/// access requires an authenticated session, and `runTransaction` is
/// all-or-nothing (a throwing body commits nothing). The atomicity asserted
/// here is the fake's transaction semantics — the production transactional
/// guarantee against a live Supabase/Neon instance is validated later (task 17
/// integration + the real client wiring), NOT here.
///
/// Architecture rule (design.md): this service is pure Dart. It depends on
/// `domain`, the sibling application services (`AllocationService`,
/// `BillingService`), the `AuthService` gate, and the `HostedDatabase` seam
/// only, and MUST NOT import `package:flutter/*` or `dart:io`, so it runs
/// headless under `flutter test` on Windows with no network.
library;

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/allocation_service.dart';
import 'package:wood_cft/application/auth_service.dart';
import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/data/hosted_database.dart';
import 'package:wood_cft/domain/cft.dart';
import 'package:wood_cft/domain/money.dart';

/// Confirmed authoritative availability for one stock item at finalize time.
///
/// The finalize transaction REVALIDATES against this confirmed balance
/// (Requirement 12.6, 19.8): only confirmed stock is sellable, and a sold line
/// may never exceed it. The caller builds the snapshot from the authoritative
/// store (via `InventoryQueryService` / the hosted read); the service stays
/// headless and takes a plain record so the revalidation is trivially testable.
@immutable
class ConfirmedStock {
  /// Creates a confirmed-availability entry for [stockItemId].
  ConfirmedStock({
    required this.stockItemId,
    required this.confirmedPieces,
  }) {
    if (confirmedPieces < 0) {
      throw ArgumentError.value(
        confirmedPieces,
        'confirmedPieces',
        'confirmed available pieces must not be negative',
      );
    }
  }

  /// The stock item this confirmed balance is for.
  final int stockItemId;

  /// Confirmed (sellable) pieces available. Never includes pending receiving
  /// stock (Requirement 19.8).
  final int confirmedPieces;
}

/// The pricing / catalog identity snapshotted onto a sold line at finalize time.
///
/// Finalize writes **immutable** `InvoiceLine` snapshots: the variety
/// [varietyName], the human [label] (e.g. `2 x 1 in, 6 ft`), and the exact
/// [rate] (`₹/CFT`)
/// are copied onto the line so a subsequent catalog rename or price change can
/// never alter an issued invoice (Requirement 12.4; task 11.4). The caller
/// resolves these from the live catalog/pricing for each allocation line and
/// pairs them by `stockItemId`.
@immutable
class LineSnapshotInput {
  /// Creates the snapshot inputs for the line drawn from [stockItemId].
  LineSnapshotInput({
    required this.stockItemId,
    required this.varietyId,
    required this.varietyName,
    required this.label,
    required this.rate,
  }) {
    if (rate <= Rational.zero) {
      // A missing / non-positive rate is an invalid sold line; finalize blocks
      // on it (Requirement 4.7, 12.6). Guarded at construction so a caller
      // cannot smuggle an unpriced line into the transaction.
      throw ArgumentError.value(
        rate,
        'rate',
        'rate (₹/CFT) must be strictly positive — a sold line must be priced',
      );
    }
    if (varietyName.trim().isEmpty) {
      throw ArgumentError.value(
        varietyName,
        'varietyName',
        'variety name snapshot must not be empty',
      );
    }
  }

  /// The source stock item this snapshot describes.
  final int stockItemId;

  /// The source variety id (identity only; the name below is the snapshot).
  final int varietyId;

  /// The variety name copied onto the invoice line (immutable snapshot).
  final String varietyName;

  /// The human-readable SKU label copied onto the invoice line (immutable
  /// snapshot), e.g. `2 x 1 in, 6 ft`.
  final String label;

  /// The exact `₹/CFT` rate copied onto the invoice line (immutable snapshot).
  final Rational rate;
}

/// A single immutable sold-line snapshot on a finalized [FinalizedInvoice].
///
/// Everything a reprint/export needs is captured here so the line is
/// independent of any later catalog/price edit (Requirement 12.4): the
/// snapshotted variety [varietyName] + [label] + [rate], the exact allocated
/// [cft], the deducted [pieces], and the line [amount] (rounded half-up to
/// paise — Requirement 9.2).
@immutable
class InvoiceLineSnapshot {
  /// Creates an immutable invoice-line snapshot.
  const InvoiceLineSnapshot({
    required this.stockItemId,
    required this.varietyId,
    required this.varietyName,
    required this.label,
    required this.lengthFt,
    required this.pieces,
    required this.cft,
    required this.rate,
    required this.amount,
  });

  /// The source stock item the pieces were deducted from.
  final int stockItemId;

  /// The source variety id.
  final int varietyId;

  /// The snapshotted variety name (immutable on this invoice).
  final String varietyName;

  /// The snapshotted SKU label (immutable on this invoice).
  final String label;

  /// The piece length in feet.
  final int lengthFt;

  /// The pieces deducted for this line (the confirmed `Sale` quantity).
  final int pieces;

  /// The exact allocated volume for this line.
  final Cft cft;

  /// The snapshotted exact `₹/CFT` rate (immutable on this invoice).
  final Rational rate;

  /// The line amount, exact CFT x rate rounded half-up to paise (Req 9.1, 9.2).
  final Money amount;

  @override
  String toString() =>
      'InvoiceLineSnapshot(stockItemId: $stockItemId, $varietyName $label, '
      'pieces: $pieces, cft: ${cft.toFixed()}, rate: $rate, '
      'amount: ${amount.format()})';
}

/// The permanent result of a successful finalize: the issued invoice.
///
/// Carries the invoice [number] allocated inside the transaction, the
/// authenticated [ownerId] it was issued under, the immutable [lines], the
/// [totals] (goods / tax / loading / payable), and the finalize
/// [idempotencyKey] that was recorded. Returned only when the whole transaction
/// committed; a blocked finalize throws instead and yields no invoice.
@immutable
class FinalizedInvoice {
  /// Creates a finalized-invoice result.
  const FinalizedInvoice({
    required this.number,
    required this.ownerId,
    required this.lines,
    required this.totals,
    required this.idempotencyKey,
  });

  /// The permanent invoice number allocated inside the finalize transaction.
  final int number;

  /// The authenticated owner id the invoice was issued under.
  final String ownerId;

  /// The immutable sold-line snapshots, in allocation order.
  final List<InvoiceLineSnapshot> lines;

  /// The money totals (goods subtotal, tax, loading, payable, total CFT).
  final InvoiceTotals totals;

  /// The idempotency key recorded for this finalize effect.
  final String idempotencyKey;

  @override
  String toString() =>
      'FinalizedInvoice(number: $number, ownerId: $ownerId, '
      'lines: ${lines.length}, payable: ${totals.payable.format()})';
}

/// Thrown when finalize is blocked during in-transaction revalidation.
///
/// The enclosing `HostedDatabase.runTransaction` body throws this, which rolls
/// the whole transaction back: no invoice is written, no invoice number is
/// consumed, and no stock is deducted — the authoritative state is left exactly
/// as the pre-finalization state (Requirement 12.4, 12.6, 21.15, 21.20).
class FinalizeBlockedException implements Exception {
  /// Creates the exception with a human-readable [reason] and a machine
  /// [kind] (missing rate vs insufficient stock).
  const FinalizeBlockedException(this.kind, this.reason);

  /// What blocked the finalize.
  final FinalizeBlockReason kind;

  /// Human-readable explanation (surfaced to the owner).
  final String reason;

  @override
  String toString() => 'FinalizeBlockedException(${kind.name}): $reason';
}

/// Why a finalize was blocked during revalidation.
enum FinalizeBlockReason {
  /// A sold line referenced a stock item with no confirmed-stock entry, or an
  /// allocation line had no paired snapshot/rate.
  missingData,

  /// A sold line had no valid (strictly positive) rate (Requirement 4.7).
  missingRate,

  /// A sold line exceeded the confirmed available stock (Requirement 12.6).
  insufficientStock,
}

/// Allocates the permanent invoice number INSIDE the finalize transaction.
///
/// The number is a hosted-side sequence assigned only inside the transaction;
/// a rolled-back attempt never consumes a number, and gaps from rolled-back
/// attempts are acceptable (Requirement 12.4; design.md -> Invoice-number
/// allocation). Implementations must only advance the sequence when called, so
/// a finalize that throws before calling it leaves the sequence untouched.
abstract interface class InvoiceNumberAllocator {
  /// Returns the next permanent invoice number and advances the sequence.
  int next();
}

/// A simple in-memory [InvoiceNumberAllocator] starting from a seed.
///
/// Models the hosted sequence for the fake-backed verification: it advances
/// only when [next] is called, so a rolled-back finalize (which throws before
/// reaching allocation) never consumes a number. The real sequence lives in the
/// hosted DB (deferred).
class InMemoryInvoiceNumberAllocator implements InvoiceNumberAllocator {
  /// Creates the allocator; the first [next] returns [start] (default `1`).
  InMemoryInvoiceNumberAllocator({int start = 1}) : _nextNumber = start;

  int _nextNumber;

  /// The number the next [next] call will return (visible for testing).
  @visibleForTesting
  int get peek => _nextNumber;

  @override
  int next() => _nextNumber++;
}

/// Finalizes a priced, allocated order into a permanent invoice as a single
/// authenticated hosted transaction (task 11.1).
///
/// Pure application-layer orchestration over the [HostedDatabase] seam and the
/// [AuthService] gate; holds no state of its own. One instance can be shared.
class FinalizeService {
  /// Creates the finalize service over the authoritative [hostedDatabase] and
  /// the [authService] gate, pricing lines with [billing] (defaults to a
  /// `const BillingService()`).
  const FinalizeService({
    required HostedDatabase hostedDatabase,
    required AuthService authService,
    BillingService billing = const BillingService(),
  })  : _hosted = hostedDatabase,
        _auth = authService,
        // ignore: prefer_initializing_formals
        _billing = billing;

  final HostedDatabase _hosted;
  final AuthService _auth;
  final BillingService _billing;

  /// Finalizes [allocation] into a permanent invoice in ONE authenticated,
  /// all-or-nothing hosted transaction.
  ///
  /// Inputs:
  ///   * [allocation] — the fully-allocated order (its [OrderAllocation.lines]
  ///     are the sold lines; a partial order should be resolved before
  ///     finalize, but any line here is validated regardless);
  ///   * [snapshots] — the per-stock-item pricing/catalog snapshot inputs
  ///     ([LineSnapshotInput]) keyed by `stockItemId`; every sold line MUST
  ///     have one or finalize is blocked;
  ///   * [confirmedStock] — the confirmed available pieces per stock item at
  ///     finalize time, revalidated inside the transaction;
  ///   * [taxMode] — the single literal tax line to apply;
  ///   * [numberAllocator] — allocates the permanent invoice number INSIDE the
  ///     transaction (step 3);
  ///   * [idempotencyKey] — the stable key the hosted effect is recorded under;
  ///   * [policy] — optional loading policy (defaults to the standard tiers);
  ///   * [onDeductStock] — optional hook invoked once per sold line INSIDE the
  ///     transaction with the signed `Sale` deduction (negative pieces), so a
  ///     caller can mirror the deduction into a local ledger within the same
  ///     all-or-nothing boundary. A throw from the hook aborts the whole
  ///     transaction (nothing commits).
  ///
  /// Behaviour (design.md -> Transaction Boundaries & Sync (d)):
  ///   1. requires an authenticated session (via `runTransaction`); with none
  ///      the order stays a draft and `NotAuthenticatedException` is thrown
  ///      (Req 12.2, 12.3b, 19.3);
  ///   2. revalidates every sold line's rate and confirmed stock; blocks with
  ///      [FinalizeBlockedException] on a missing rate or insufficient stock —
  ///      which rolls the transaction back, so NO invoice and NO deduction
  ///      occur (Req 4.7, 12.6, 21.15);
  ///   3. on success, writes the invoice + immutable line snapshots, allocates
  ///      the invoice number, deducts stock via `Sale` movements, and records
  ///      the idempotency key — all committed together (Req 12.2, 12.4);
  ///   4. is **idempotent under [idempotencyKey]**: if the key was already
  ///      applied (a retry after a lost/timed-out response), it reuses the
  ///      original invoice number, stages no second effect, and does NOT re-run
  ///      [onDeductStock] — so a retry produces exactly one invoice and one
  ///      deduction (Req 12.3, 12.3a; Req 21.7, 21.26; task 11.2).
  ///
  /// Returns the [FinalizedInvoice] only when the whole transaction commits (or,
  /// on an idempotent retry, the equivalent result for the already-committed
  /// finalize).
  Future<FinalizedInvoice> finalizeSale({
    required OrderAllocation allocation,
    required Map<int, LineSnapshotInput> snapshots,
    required List<ConfirmedStock> confirmedStock,
    required TaxMode taxMode,
    required InvoiceNumberAllocator numberAllocator,
    required String idempotencyKey,
    LoadingPolicy? policy,
    FutureOr<void> Function(int stockItemId, int deltaPieces)? onDeductStock,
  }) async {
    // Require an authenticated owner session up front, so the order stays a
    // draft with NO hosted call attempted when signed out (Req 12.2, 12.3b,
    // 19.3). The hosted transaction re-checks this too, so the gate holds even
    // if a caller bypasses the service.
    _auth.requireSession('finalize sale');

    final confirmedByItem = <int, int>{
      for (final c in confirmedStock) c.stockItemId: c.confirmedPieces,
    };

    // --- Idempotent exactly-once retry (task 11.2; Req 12.3, 12.3a).
    // Read the authoritative confirmed state recorded under this finalize key.
    // If it exists, the first finalize already committed exactly one invoice +
    // one deduction, and THIS call is a retry (e.g. after a lost/timed-out
    // response). We must NOT allocate a new number, stage a second effect, or
    // re-run onDeductStock; we return the equivalent original invoice instead
    // (Req 21.7, 21.26; Property 19). readConfirmed is session-gated, so the
    // auth guarantee still holds. A missing key means this is the first attempt
    // and we take the full transactional path below.
    int? priorInvoiceNumber;
    try {
      final confirmed = await _hosted.readConfirmed(idempotencyKey);
      final n = confirmed['invoiceNumber'];
      priorInvoiceNumber = n is int ? n : int.tryParse('$n');
    } on HostedStateNotFoundException {
      priorInvoiceNumber = null; // first finalize for this key
    }

    // The entire effect runs inside ONE authenticated transaction. The session
    // check also lives in runTransaction (AuthService.requireSession): no
    // session -> NotAuthenticatedException and nothing is staged/committed
    // (Req 19.3).
    return await _hosted.runTransaction<FinalizedInvoice>((txn) async {
      // --- Step 1: Revalidate confirmed stock and that every line is priced.
      // We validate BEFORE allocating a number or staging any write, so a block
      // throws out of the body and the transaction rolls back with no partial
      // effect (Req 12.4, 12.6). Track per-item demand so repeated draws from
      // the same stock item are summed against the one confirmed balance.
      final demandByItem = <int, int>{};
      final lineSnapshots = <InvoiceLineSnapshot>[];
      final goodsInputs = <GoodsLineInput>[];

      for (final line in allocation.lines) {
        final snap = snapshots[line.stockItemId];
        if (snap == null) {
          throw FinalizeBlockedException(
            FinalizeBlockReason.missingData,
            'no pricing/catalog snapshot for stock item ${line.stockItemId}',
          );
        }
        // Rate validity is also guarded at LineSnapshotInput construction, but
        // re-assert here so the block reason is explicit (Req 4.7, 12.6).
        if (snap.rate <= Rational.zero) {
          throw FinalizeBlockedException(
            FinalizeBlockReason.missingRate,
            'stock item ${line.stockItemId} has no valid rate',
          );
        }

        final confirmed = confirmedByItem[line.stockItemId];
        if (confirmed == null) {
          throw FinalizeBlockedException(
            FinalizeBlockReason.missingData,
            'no confirmed-stock entry for stock item ${line.stockItemId}',
          );
        }

        final runningDemand =
            (demandByItem[line.stockItemId] ?? 0) + line.allocatedPieces;
        demandByItem[line.stockItemId] = runningDemand;
        if (runningDemand > confirmed) {
          // Insufficient confirmed stock -> block. All-or-nothing: nothing has
          // been staged yet and the number is unallocated (Req 12.6, 21.15).
          throw FinalizeBlockedException(
            FinalizeBlockReason.insufficientStock,
            'stock item ${line.stockItemId} needs $runningDemand pieces but '
            'only $confirmed are confirmed-available',
          );
        }

        final amount = _billing.lineAmount(line.allocatedCft, snap.rate);
        lineSnapshots.add(
          InvoiceLineSnapshot(
            stockItemId: line.stockItemId,
            varietyId: snap.varietyId,
            varietyName: snap.varietyName,
            label: snap.label,
            lengthFt: line.lengthFt,
            pieces: line.allocatedPieces,
            cft: line.allocatedCft,
            rate: snap.rate,
            amount: amount,
          ),
        );
        goodsInputs.add(
          GoodsLineInput(
            stockItemId: line.stockItemId,
            varietyId: snap.varietyId,
            crossSectionId: line.crossSectionId,
            lengthFt: line.lengthFt,
            allocatedCft: line.allocatedCft,
            rate: snap.rate,
          ),
        );
      }

      // Compute the authoritative totals from the same priced lines (goods
      // subtotal = sum of rounded line amounts; tax; loading; payable).
      final goods = _billing.computeGoods(goodsInputs);
      final totals = _billing.computeTotals(goods, taxMode, policy: policy);

      // --- Idempotent-retry fast path: the key is already applied.
      // The first finalize committed exactly one invoice (number
      // [priorInvoiceNumber]) and one deduction. Reuse that number, stage NO
      // second effect, and do NOT re-run onDeductStock, then return the
      // equivalent invoice recomputed from the same deterministic inputs
      // (Req 12.3, 12.3a, 21.7, 21.26; Property 19). No number is consumed from
      // numberAllocator on a retry.
      if (priorInvoiceNumber != null) {
        return FinalizedInvoice(
          number: priorInvoiceNumber,
          ownerId: txn.session.userId,
          lines: List<InvoiceLineSnapshot>.unmodifiable(lineSnapshots),
          totals: totals,
          idempotencyKey: idempotencyKey,
        );
      }

      // --- Step 3: Allocate the permanent invoice number INSIDE the txn.
      // Reached only after validation passed AND only on the first finalize for
      // this key, so a blocked OR a retried finalize never consumes a number
      // (gaps from rolled-back attempts are acceptable — Req 12.4).
      final number = numberAllocator.next();

      // --- Step 2: Stage the Invoice row + immutable InvoiceLine snapshots.
      txn.stage(
        HostedOperation(
          kind: 'finalizeInvoice',
          idempotencyKey: idempotencyKey,
          payload: <String, Object?>{
            'invoiceNumber': number,
            'ownerId': txn.session.userId,
            'payablePaise': totals.payable.paise.toString(),
            'lineCount': lineSnapshots.length,
          },
        ),
      );

      // --- Step 4: Deduct stock via confirmed Sale movements. One signed
      // deduction per line, staged inside the same transaction and mirrored to
      // the optional local-ledger hook. A hook throw aborts everything.
      for (final line in allocation.lines) {
        final delta = -line.allocatedPieces;
        txn.stage(
          HostedOperation(
            kind: 'finalizeSaleMovement',
            idempotencyKey: '$idempotencyKey:sale:${line.stockItemId}:'
                '${line.lengthFt}',
            payload: <String, Object?>{
              'stockItemId': line.stockItemId,
              'deltaPieces': delta,
              'invoiceNumber': number,
            },
          ),
        );
        if (onDeductStock != null) {
          await onDeductStock(line.stockItemId, delta);
        }
      }

      // --- Step 5: Record the finalize idempotency key (the invoice op above
      // is keyed by it; its presence in the committed state is the record).
      return FinalizedInvoice(
        number: number,
        ownerId: txn.session.userId,
        lines: List<InvoiceLineSnapshot>.unmodifiable(lineSnapshots),
        totals: totals,
        idempotencyKey: idempotencyKey,
      );
    });
  }
}

/// The permanent result of a successful void: the recorded reversal (task 11.3).
///
/// A void never mutates the original immutable [FinalizedInvoice]; it records a
/// **separate** reversal that marks the invoice `Voided` (the original is
/// retained, never deleted — Requirement 13.2) and restores exactly the pieces
/// the finalize deducted (Requirement 13.1). This result carries the voided
/// invoice [number], the authenticated [ownerId] the void was recorded under,
/// the per-stock-item [restoredPieces] (positive `Void` movement quantities,
/// mirroring the original negative `Sale` deductions), and the void
/// [idempotencyKey] recorded for the reversal.
///
/// Returned only when the whole void transaction commits (or, on an idempotent
/// retry, the equivalent result for the already-recorded void).
@immutable
class VoidedInvoice {
  /// Creates a void result for invoice [number].
  const VoidedInvoice({
    required this.number,
    required this.ownerId,
    required this.restoredPieces,
    required this.idempotencyKey,
  });

  /// The permanent number of the invoice that was voided (unchanged from the
  /// original — the void references it, it is not re-allocated).
  final int number;

  /// The authenticated owner id the void was recorded under.
  final String ownerId;

  /// The pieces restored per stock item (positive — the exact reverse of the
  /// original `Sale` deductions), keyed by `stockItemId`. Repeated draws from
  /// the same stock item are summed into one restore quantity.
  final Map<int, int> restoredPieces;

  /// The idempotency key recorded for this void (reversal) effect.
  final String idempotencyKey;

  @override
  String toString() =>
      'VoidedInvoice(number: $number, ownerId: $ownerId, '
      'restored: $restoredPieces)';
}

/// Thrown when a void is blocked during in-transaction validation.
///
/// The enclosing `HostedDatabase.runTransaction` body throws this, which rolls
/// the whole transaction back: the invoice is NOT marked voided and NO stock is
/// restored — the authoritative state is left exactly as before (Requirement
/// 13.1, 13.2).
class VoidBlockedException implements Exception {
  /// Creates the exception with a human-readable [reason].
  const VoidBlockedException(this.reason);

  /// Human-readable explanation (surfaced to the owner).
  final String reason;

  @override
  String toString() => 'VoidBlockedException: $reason';
}

/// Voids a finalized invoice as a single authenticated hosted transaction
/// (task 11.3).
///
/// Implements design.md -> Transaction Boundaries & Sync -> **(e) Void**: in ONE
/// authenticated, all-or-nothing `HostedDatabase.runTransaction` it marks the
/// `Invoice` `Voided` (the original is **retained, never deleted** —
/// Requirement 13.2), inserts `Void` movements that restore **exactly** the
/// pieces the original finalize deducted (Requirement 13.1), updates balances
/// (mirrored via the optional `onRestoreStock` hook), and records the void
/// `idempotency_key`. A retried void restores stock **exactly once**
/// (Requirement 13.3, 21.23; Property 25-adjacent).
///
/// Pure application-layer orchestration over the same [HostedDatabase] seam and
/// [AuthService] gate the finalize path uses; holds no state of its own and
/// mirrors the finalize transaction pattern so previews/invoices can never
/// disagree. The original [FinalizedInvoice] snapshot is treated as immutable:
/// the void NEVER mutates it, it records a separate reversal referencing the
/// same invoice number.
///
/// ## Verified against the in-memory fake, not real Supabase/Neon (deferred)
///
/// As with finalize, this is written against the pure [HostedDatabase]
/// interface and verified against the in-memory `FakeHostedDatabase` (whose
/// keyed `apply`/`stage` collapse a duplicate key to a single effect). The
/// production transactional + exactly-once guarantee against a live
/// Supabase/Neon instance is deferred (task 17 integration + the real client
/// wiring), NOT here.
extension FinalizeServiceVoid on FinalizeService {
  /// Voids [invoice] in ONE authenticated, all-or-nothing hosted transaction,
  /// restoring the deducted stock exactly once.
  ///
  /// Inputs:
  ///   * [invoice] — the original finalized invoice to reverse. It is NOT
  ///     mutated; the void records a separate reversal referencing its
  ///     [FinalizedInvoice.number] and reverses its line deductions;
  ///   * [idempotencyKey] — the stable key the void (reversal) effect is
  ///     recorded under. Retrying with the SAME key restores stock exactly once
  ///     (Req 13.3, 21.23);
  ///   * [onRestoreStock] — optional hook invoked once per restored stock item
  ///     INSIDE the transaction with the signed `Void` restore (positive
  ///     pieces), so a caller can mirror the restore into a local ledger within
  ///     the same all-or-nothing boundary. A throw from the hook aborts the
  ///     whole transaction (nothing commits).
  ///
  /// Behaviour (design.md -> Transaction Boundaries & Sync (e)):
  ///   1. requires an authenticated session (via `runTransaction`); with none
  ///      the void is refused with `NotAuthenticatedException` and nothing is
  ///      written (Req 13.1, 19.3);
  ///   2. is **idempotent under [idempotencyKey]**: if the key was already
  ///      applied (a retry after a lost/timed-out response), it stages no second
  ///      effect and does NOT re-run [onRestoreStock] — so a retried void
  ///      restores stock exactly once (Req 13.3, 21.23);
  ///   3. is also guarded **per invoice**: voiding the same invoice again with a
  ///      DIFFERENT key cannot double-restore — an invoice-scoped marker (keyed
  ///      by the invoice number) and invoice-number-keyed `Void` movements mean
  ///      the invoice is voided, and stock restored, at most once (Req 13.3);
  ///   4. on the first void, marks the invoice `Voided` (original retained —
  ///      Req 13.2) and stages one positive `Void` movement per deducted line
  ///      (summed per stock item), all committed together (Req 13.1).
  ///
  /// Returns the [VoidedInvoice] only when the whole transaction commits (or,
  /// on an idempotent retry, the equivalent result for the already-recorded
  /// void).
  Future<VoidedInvoice> voidSale({
    required FinalizedInvoice invoice,
    required String idempotencyKey,
    FutureOr<void> Function(int stockItemId, int deltaPieces)? onRestoreStock,
  }) async {
    // Require an authenticated owner session up front, so no hosted call is
    // attempted when signed out (Req 13.1, 19.3). runTransaction re-checks it.
    _auth.requireSession('void invoice ${invoice.number}');

    // Compute the exact restore per stock item: the positive reverse of each
    // line's deduction, summed so repeated draws from one stock item restore to
    // a single Void quantity (Req 13.1).
    final restoreByItem = <int, int>{};
    for (final line in invoice.lines) {
      if (line.pieces <= 0) {
        // A finalized line always deducted a positive piece count; a
        // non-positive snapshot would mean a corrupt invoice -> block rather
        // than restore nonsense.
        throw VoidBlockedException(
          'invoice ${invoice.number} line for stock item ${line.stockItemId} '
          'has non-positive pieces (${line.pieces})',
        );
      }
      restoreByItem[line.stockItemId] =
          (restoreByItem[line.stockItemId] ?? 0) + line.pieces;
    }

    // --- Idempotent exactly-once restore (Req 13.3, 21.23).
    //
    // Two independent guards keep "restore exactly once":
    //
    //   (1) the caller's [idempotencyKey] — a RETRY of the same void (lost /
    //       timed-out response, same key) must stage nothing new; and
    //   (2) an invoice-scoped marker keyed ONLY by the invoice number
    //       (`invoice-voided:{number}`) — so a SECOND void of the same invoice
    //       under a DIFFERENT key still cannot double-restore. The invoice is
    //       voided at most once regardless of how many void keys are tried.
    //
    // Crucially the `Void` movement idempotency keys below are also keyed by the
    // invoice number (NOT the caller's void key), so even if a different-key
    // void reached the staging path, the restore movements would collapse to
    // the same keys the first void used — stock is restored exactly once at the
    // store level too. We read both markers before opening the transaction;
    // readConfirmed is session-gated so the auth guarantee still holds. If
    // either marker is present, this is a replay and we return the equivalent
    // result without staging a second effect.
    final invoiceVoidedKey = 'invoice-voided:${invoice.number}';
    var alreadyVoided = false;
    for (final key in <String>[idempotencyKey, invoiceVoidedKey]) {
      try {
        await _hosted.readConfirmed(key);
        alreadyVoided = true;
        break;
      } on HostedStateNotFoundException {
        // not applied under this marker; keep checking
      }
    }

    // The entire effect runs inside ONE authenticated transaction. The session
    // check also lives in runTransaction (AuthService.requireSession): no
    // session -> NotAuthenticatedException and nothing is staged/committed.
    return _hosted.runTransaction<VoidedInvoice>((txn) async {
      final restored = Map<int, int>.unmodifiable(restoreByItem);

      // --- Idempotent-retry fast path: the key is already applied.
      // The first void committed exactly one reversal and restored stock once.
      // Stage NO second effect and do NOT re-run onRestoreStock, then return
      // the equivalent result (Req 13.3, 21.23).
      if (alreadyVoided) {
        return VoidedInvoice(
          number: invoice.number,
          ownerId: txn.session.userId,
          restoredPieces: restored,
          idempotencyKey: idempotencyKey,
        );
      }

      // --- Mark the Invoice Voided. The ORIGINAL snapshot is retained and NOT
      // mutated (Req 13.2): this is a separate reversal row referencing the
      // invoice number, keyed by the void idempotency key so a same-key retry
      // collapses to one effect.
      txn.stage(
        HostedOperation(
          kind: 'voidInvoice',
          idempotencyKey: idempotencyKey,
          payload: <String, Object?>{
            'invoiceNumber': invoice.number,
            'ownerId': txn.session.userId,
            'status': 'Voided',
          },
        ),
      );

      // --- Invoice-scoped "voided once" marker, keyed ONLY by the invoice
      // number. This is what guards a SECOND void of the same invoice under a
      // DIFFERENT key: once committed, any later void (any key) reads it before
      // the transaction and takes the no-op replay path above, so the invoice
      // is marked voided and stock restored exactly once (Req 13.2, 13.3,
      // 21.23).
      txn.stage(
        HostedOperation(
          kind: 'invoiceVoidedMarker',
          idempotencyKey: invoiceVoidedKey,
          payload: <String, Object?>{
            'invoiceNumber': invoice.number,
            'voidKey': idempotencyKey,
          },
        ),
      );

      // --- Insert Void movements restoring exactly the deducted pieces, one
      // signed (positive) restore per stock item, staged inside the same
      // transaction and mirrored to the optional local-ledger hook. A hook
      // throw aborts everything (all-or-nothing). Sorted by stock item id so
      // the staging order (and the hook call order) is deterministic.
      final itemIds = restoreByItem.keys.toList()..sort();
      for (final stockItemId in itemIds) {
        final delta = restoreByItem[stockItemId]!;
        txn.stage(
          HostedOperation(
            kind: 'voidMovement',
            // Keyed by the INVOICE number (not the caller's void key) so a
            // second void under a different key cannot stage a second restore —
            // the store collapses it to this same key (Req 13.3, 21.23).
            idempotencyKey: 'invoice-void-movement:${invoice.number}:'
                '$stockItemId',
            payload: <String, Object?>{
              'stockItemId': stockItemId,
              'deltaPieces': delta,
              'invoiceNumber': invoice.number,
            },
          ),
        );
        if (onRestoreStock != null) {
          await onRestoreStock(stockItemId, delta);
        }
      }

      return VoidedInvoice(
        number: invoice.number,
        ownerId: txn.session.userId,
        restoredPieces: restored,
        idempotencyKey: idempotencyKey,
      );
    });
  }
}
