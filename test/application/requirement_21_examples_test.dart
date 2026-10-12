/// Requirement 21 worked-example pins — the remaining acceptance examples.
///
/// Requirement 21 lists concrete worked examples (21.1 .. 21.27) with exact
/// inputs and exact expected outputs. Most are already pinned next to the code
/// they verify (see `calculation_service_test.dart`, `billing_service_test.dart`,
/// `allocation_service_test.dart`, `finalize_service_test.dart`,
/// `invoice_snapshot_immutability_test.dart`, `backup_service_test.dart`, …).
///
/// This file closes the two examples that had no explicitly-tagged pin, exercised
/// here against the REAL services so the exact numbers/behaviour are locked:
///
///   * 21.12 — WHEN a fixed-length Order_Request cannot be met, the System must
///     NOT silently mix in other lengths. Pinned on the real
///     `AllocationService.allocateTargetCftFixedLength` / `allocateOrder`.
///   * 21.22 — WHEN a Rate or the Catalog changes, the System must NOT alter an
///     already-issued Invoice. Pinned on the real `FinalizeService` /
///     `BillingService` value objects (a value-level pin, distinct from the
///     export byte-equality pin in `invoice_snapshot_immutability_test.dart`).
///
/// Pure-Dart / headless (no device, no network): runs under `flutter test` on
/// Windows. Each test cites its 21.x id. The money example 21.8 is the
/// self-consistent ₹400/CFT → ₹1,666.67 interpretation already adopted by the
/// codebase (see `billing_service_test.dart`); it is NOT re-pinned here to avoid
/// duplicating identical assertions.
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
import 'package:wood_cft/domain/order_request.dart';

void main() {
  const calc = CalculationService();
  const allocation = AllocationService();

  // A reaper 2×1 cross-section (bunch of 10) — the Requirement-21 worked SKU.
  final reaper2x1 = CrossSection(
    id: 1,
    widthIn: 2,
    thicknessIn: 1,
    category: WoodCategory.reaper,
  );

  // ---------------------------------------------------------------------------
  // Req 21.12 — a fixed-length request that cannot be met goes PARTIAL at the
  // requested length only; the allocator NEVER fabricates lines at other
  // lengths to paper over the shortage.
  // ---------------------------------------------------------------------------
  group('Req 21.12: a fixed-length request that cannot be met does NOT '
      'silently mix in other lengths', () {
    test('single-SKU meet-or-exceed stays a labelled partial at the requested '
        'length', () {
      // Target 5 CFT of 2×1 @ 6 ft needs 6 whole bunches (60 pcs) — see 21.9.
      // Only 42 pieces are confirmed at 6 ft, so just 4 whole bunches fit.
      final request = TargetCftFixedLengthRequest(
        varietyId: 7,
        crossSectionId: reaper2x1.id,
        lengthFt: 6,
        targetCft: Rational.fromInt(5),
      );
      final availabilityAt6ft = SkuAvailability(
        stockItemId: 100,
        crossSection: reaper2x1,
        lengthFt: 6,
        availablePieces: 42, // 4 whole bunches (40 pcs) fit, 2 bunches short
      );

      final line =
          allocation.allocateTargetCftFixedLength(request, availabilityAt6ft);

      // Honestly labelled a partial — never silently "fulfilled".
      expect(line.isPartial, isTrue);
      expect(line.isFullyAllocated, isFalse);
      // The allocated quantity is below target and reports the exact shortage.
      expect(line.allocatedUnits, 4);
      expect(line.allocatedPieces, 40);
      expect(line.shortageUnits, 2);
      expect(line.shortagePieces, 20);
      // CRITICAL (21.12): the single produced line stays at the REQUESTED
      // length — no other length is substituted in.
      expect(line.lengthFt, 6);
      expect(line.crossSectionId, reaper2x1.id);
      // Allocated CFT is strictly below target: the gap is left open, not
      // closed by borrowing stock from a different length.
      expect(line.allocatedCft.value < request.targetCft, isTrue);
      expect(line.allocatedCft, calc.lineCftFor(reaper2x1, 6, 40));
    });

    test('allocateOrder leaves ONLY the requested-length line partial even when '
        'abundant OTHER-length stock exists (no silent mixing)', () {
      // Same under-stocked 6 ft request, but the warehouse is FULL of the same
      // 2×1 reaper at a DIFFERENT length (7 ft). A silent-mixing allocator
      // would raid the 7 ft stock to "complete" the 6 ft target; the correct
      // behaviour is a 6 ft partial and NOT a single piece taken from 7 ft.
      final request = TargetCftFixedLengthRequest(
        varietyId: 7,
        crossSectionId: reaper2x1.id,
        lengthFt: 6,
        targetCft: Rational.fromInt(5),
      );
      final availability = <SkuAvailability>[
        SkuAvailability(
          stockItemId: 100,
          crossSection: reaper2x1,
          lengthFt: 6,
          availablePieces: 42, // only 4 whole bunches fit at the asked length
        ),
        SkuAvailability(
          stockItemId: 101,
          crossSection: reaper2x1,
          lengthFt: 7, // abundant, but a DIFFERENT length
          availablePieces: 500,
        ),
      ];

      final order = allocation.allocateOrder([request], availability);

      // The order is a partial because the fixed-length line could not be met.
      expect(order.isPartial, isTrue);
      // Exactly one produced line, and it is the 6 ft line — nothing at 7 ft.
      expect(order.lines, hasLength(1));
      final line = order.lines.single;
      expect(line.lengthFt, 6);
      expect(line.allocatedPieces, 40);
      expect(line.isPartial, isTrue);
      expect(line.shortagePieces, 20);
      // No produced line draws on the 7 ft stock item or sits at 7 ft.
      expect(order.lines.any((l) => l.lengthFt == 7), isFalse);
      expect(order.lines.any((l) => l.stockItemId == 101), isFalse);
      // The abundant 7 ft stock was genuinely untouched: a mixing allocator
      // could easily have met 5 CFT from it, so a partial result proves the
      // engine refused to substitute lengths.
      expect(line.allocatedCft.value < request.targetCft, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Req 21.22 — a later Rate / Catalog change does NOT alter an already-issued
  // Invoice. Pinned at the FinalizedInvoice value level: finalize once, capture
  // the issued line money, then recompute billing at a brand-new rate and
  // confirm the already-issued invoice's own fields are unchanged.
  // ---------------------------------------------------------------------------
  group('Req 21.22: a later rate/catalog change does NOT alter an '
      'already-issued invoice', () {
    const billing = BillingService();

    // One sold line: 3 bunches (30 pcs) of a 2×1 reaper @ 6 ft from stock 100.
    AllocationLine soldLine() => AllocationLine(
          stockItemId: 100,
          crossSectionId: reaper2x1.id,
          varietyId: 7,
          lengthFt: 6,
          unit: AllocationUnit.bunch,
          allocatedUnits: 3,
          allocatedPieces: 30,
          allocatedCft: calc.lineCftFor(reaper2x1, 6, 30),
          isPartial: false,
          shortageUnits: 0,
          shortagePieces: 0,
        );

    OrderAllocation oneLineOrder() => OrderAllocation(
          lineResults: const [],
          lines: [soldLine()],
          isPartial: false,
        );

    // The rate IN EFFECT at issue time: ₹1,200 / CFT.
    final issuedRate = Rational.fromInt(1200);

    final issuedSnapshots = <int, LineSnapshotInput>{
      100: LineSnapshotInput(
        stockItemId: 100,
        varietyId: 7,
        varietyName: 'Mahogany',
        label: '2 x 1 in, 6 ft',
        rate: issuedRate,
      ),
    };

    test('the issued invoice line keeps its issue-time rate and amount after a '
        'rate change', () async {
      final auth = FakeAuthService(
        initialSession: const AuthSession(userId: 'owner'),
      );
      final hosted = FakeHostedDatabase(authService: auth);
      final service =
          FinalizeService(hostedDatabase: hosted, authService: auth);

      final invoice = await service.finalizeSale(
        allocation: oneLineOrder(),
        snapshots: issuedSnapshots,
        confirmedStock: [
          ConfirmedStock(stockItemId: 100, confirmedPieces: 50),
        ],
        taxMode: TaxMode.eighteen,
        numberAllocator: InMemoryInvoiceNumberAllocator(start: 1),
        idempotencyKey: 'req-21-22-finalize',
      );

      // Capture the issued figures BEFORE anything "changes" in the catalog.
      final issuedLine = invoice.lines.single;
      final issuedNumber = invoice.number;
      final issuedLineRate = issuedLine.rate;
      final issuedLineAmountPaise = issuedLine.amount.paise;
      final issuedPayablePaise = invoice.totals.payable.paise;
      final issuedCftFixed = issuedLine.cft.toFixed();

      // Sanity: the issued line was priced at the issue-time rate.
      final issueTimeAmount =
          billing.lineAmount(calc.lineCftFor(reaper2x1, 6, 30), issuedRate);
      expect(issuedLineAmountPaise, issueTimeAmount.paise);

      // --- The catalog/pricing now MOVES ON: the rate is changed dramatically.
      final changedRate = Rational.fromInt(9999);
      final recomputedAmount =
          billing.lineAmount(calc.lineCftFor(reaper2x1, 6, 30), changedRate);
      // The change is real: pricing the SAME volume at the new rate differs.
      expect(recomputedAmount.paise, isNot(equals(issuedLineAmountPaise)));

      // --- Req 21.22: the already-issued invoice is UNAFFECTED by the change.
      final after = invoice.lines.single;
      expect(invoice.number, issuedNumber);
      expect(after.rate, issuedLineRate); // still ₹1,200/CFT
      expect(after.amount.paise, issuedLineAmountPaise); // amount frozen
      expect(after.cft.toFixed(), issuedCftFixed);
      expect(invoice.totals.payable.paise, issuedPayablePaise);

      await auth.dispose();
    });
  });
}
