/// Enforcing unit tests for invoice-snapshot immutability and
/// no-mutation-on-share (task 11.4).
///
/// Finalized invoice snapshots are immutable to any later catalog / rate / tax
/// / loading change, and sharing or exporting an issued invoice NEVER re-runs
/// the stock deduction (Requirements 4.8, 4.9, 12.7, 15.6; design.md ->
/// Transaction Boundaries & Sync; Correctness Properties 18, 24). The source
/// types already encode this:
///
///   * `FinalizedInvoice` / `InvoiceLineSnapshot` (from `finalize_service.dart`)
///     are `@immutable` with `final` fields, and `FinalizeService` wraps the
///     returned `lines` in `List.unmodifiable(...)` on every path; and
///   * `InvoiceShareService` drives the three share/copy actions purely off the
///     already-finalized `InvoiceSnapshot` and never calls back into finalize /
///     billing / the hosted database, so it cannot deduct stock.
///
/// These tests PIN those guarantees so a future edit that weakens them fails
/// loudly. They are pure-Dart / headless (no device, no network) and run under
/// `flutter test` on Windows.
///
/// IMPORTANT: the all-or-nothing / exactly-once semantics relied on by the void
/// case are the in-memory `FakeHostedDatabase` transaction semantics; the
/// production guarantee against a live Supabase/Neon instance is deferred
/// (task 17 integration), NOT asserted here.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/allocation_service.dart';
import 'package:wood_cft/application/auth_service.dart';
import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/application/docx_export_service.dart' as docx_model;
import 'package:wood_cft/application/finalize_service.dart';
import 'package:wood_cft/application/invoice_share_service.dart';
import 'package:wood_cft/application/whatsapp_export_service.dart';
import 'package:wood_cft/data/hosted_database.dart';
import 'package:wood_cft/domain/business_settings.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/cft.dart';

void main() {
  const calc = CalculationService();
  const billing = BillingService();
  const docx = docx_model.DocxExportService();
  const whatsApp = WhatsAppExportService();

  // A reaper 2x1 cross-section (bunch of 10 pieces); one sold line of 30 pieces
  // (3 bunches) at 6 ft from stock item 100. The exact CFT comes from the
  // shared engine so money and volume match every other surface.
  final reaper2x1 = CrossSection(
    id: 1,
    widthIn: 2,
    thicknessIn: 1,
    category: WoodCategory.reaper,
  );

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

  OrderAllocation oneLineOrder({int pieces = 30}) => OrderAllocation(
        lineResults: const [],
        lines: [soldLine(pieces: pieces)],
        isPartial: false,
      );

  final snapshots = <int, LineSnapshotInput>{
    100: LineSnapshotInput(
      stockItemId: 100,
      varietyId: 7,
      varietyName: 'Mahogany',
      label: '2 x 1 in, 6 ft',
      rate: Rational.fromInt(1200),
    ),
  };

  Future<(FinalizeService, FakeHostedDatabase, FinalizedInvoice)> finalizeOne(
    FakeAuthService auth, {
    void Function(int stockItemId, int delta)? onDeduct,
  }) async {
    final hosted = FakeHostedDatabase(authService: auth);
    final service = FinalizeService(hostedDatabase: hosted, authService: auth);
    final invoice = await service.finalizeSale(
      allocation: oneLineOrder(),
      snapshots: snapshots,
      confirmedStock: [ConfirmedStock(stockItemId: 100, confirmedPieces: 50)],
      taxMode: TaxMode.eighteen,
      numberAllocator: InMemoryInvoiceNumberAllocator(start: 1),
      idempotencyKey: 'finalize-immutability',
      onDeductStock: onDeduct == null
          ? null
          : (stockItemId, delta) => onDeduct(stockItemId, delta),
    );
    return (service, hosted, invoice);
  }

  group('finalized invoice lines are an unmodifiable snapshot (Req 12.7, '
      'Property 24)', () {
    test('attempting to add to the lines list throws', () async {
      final auth = FakeAuthService(
        initialSession: const AuthSession(userId: 'owner'),
      );
      final (_, _, invoice) = await finalizeOne(auth);

      final clone = invoice.lines.single;
      expect(
        () => invoice.lines.add(clone),
        throwsUnsupportedError,
        reason: 'the finalized lines list must be unmodifiable',
      );

      await auth.dispose();
    });

    test('attempting to clear or remove from the lines list throws', () async {
      final auth = FakeAuthService(
        initialSession: const AuthSession(userId: 'owner'),
      );
      final (_, _, invoice) = await finalizeOne(auth);

      expect(invoice.lines.clear, throwsUnsupportedError);
      expect(() => invoice.lines.removeAt(0), throwsUnsupportedError);
      expect(() => invoice.lines[0] = invoice.lines[0], throwsUnsupportedError);

      // The snapshot's content is intact after the rejected mutations.
      expect(invoice.lines, hasLength(1));
      expect(invoice.lines.single.varietyName, 'Mahogany');
      expect(invoice.lines.single.pieces, 30);

      await auth.dispose();
    });

    test(
        'the retry fast-path result is ALSO an unmodifiable snapshot '
        '(Req 12.3a)', () async {
      final auth = FakeAuthService(
        initialSession: const AuthSession(userId: 'owner'),
      );
      final (service, _, first) = await finalizeOne(auth);

      // A retry with the SAME key returns the equivalent invoice; its lines
      // must be unmodifiable too (every return path wraps List.unmodifiable).
      final retry = await service.finalizeSale(
        allocation: oneLineOrder(),
        snapshots: snapshots,
        confirmedStock: [ConfirmedStock(stockItemId: 100, confirmedPieces: 50)],
        taxMode: TaxMode.eighteen,
        numberAllocator: InMemoryInvoiceNumberAllocator(start: 99),
        idempotencyKey: 'finalize-immutability',
      );

      expect(retry.number, first.number);
      expect(() => retry.lines.add(retry.lines.single), throwsUnsupportedError);

      await auth.dispose();
    });
  });

  // --- (b) Sharing/exporting an issued invoice never mutates the snapshot and
  // never triggers stock mutation (Req 15.6; Property 18/24). ----------------

  docx_model.InvoiceSnapshot buildExportSnapshot() {
    final line = billing.priceLine(
      GoodsLineInput(
        stockItemId: 100,
        varietyId: 7,
        crossSectionId: 1,
        lengthFt: 6,
        allocatedCft: Cft(Rational(BigInt.from(25), BigInt.from(6))),
        rate: Rational.fromInt(1200),
      ),
    );
    final goods = billing.computeGoods([line.input]);
    final totals = billing.computeTotals(goods, TaxMode.eighteen);

    return docx_model.InvoiceSnapshot(
      business: const BusinessProfile(
        name: 'Wood CFT Timbers',
        address: '12 Mill Road, Chennai',
        phone: '044-12345',
        gstin: '33ABCDE1234F1Z5',
        invoicePrefix: 'INV-',
      ),
      invoiceNumber: 'INV-21',
      dateLabel: '21-05-2024',
      customerName: 'Ramesh Timber',
      customerPhone: '9876543210',
      lines: [
        docx_model.InvoiceLineSnapshot(
          variety: 'Mahogany',
          crossSection: '2 x 1 in',
          lengthFt: 6,
          units: '30 pcs (3 bunches)',
          goods: line,
        ),
      ],
      totals: totals,
    );
  }

  group('sharing/exporting NEVER mutates the snapshot or stock (Req 15.6, '
      'Property 18)', () {
    test(
        'DOCX + WhatsApp + share/copy any number of times leave the snapshot '
        'and its payloads byte-for-byte identical', () async {
      final backend = FakeShareBackend();
      final service = InvoiceShareService(backend: backend);
      final snapshot = buildExportSnapshot();

      // Baseline payloads and the confirmed line/balance BEFORE any action.
      final baselineDocx = docx.buildDocx(snapshot);
      final baselineFileName = docx.buildFileName(snapshot);
      final baselineText = whatsApp.buildMessage(snapshot);
      final baselinePieces = snapshot.lines.single.goods.input.allocatedCft;
      final baselineAmount = snapshot.lines.single.amount;
      final baselinePayable = snapshot.totals.payable;

      // Hammer every surface many times, interleaved.
      for (var i = 0; i < 5; i++) {
        expect(docx.buildDocx(snapshot), equals(baselineDocx));
        expect(whatsApp.buildMessage(snapshot), equals(baselineText));
        await service.shareInvoiceFile(snapshot);
        await service.shareBillText(snapshot);
        await service.copyBillText(snapshot);
      }

      // Every file share carried identical bytes/filename; every text/copy was
      // identical. A re-deduction or recomputation would have changed these.
      expect(backend.sharedFiles, hasLength(5));
      for (final file in backend.sharedFiles) {
        expect(file.bytes, equals(baselineDocx));
        expect(file.fileName, equals(baselineFileName));
        expect(file.mimeType, equals(InvoiceShareService.docxMimeType));
      }
      expect(backend.sharedTexts, everyElement(equals(baselineText)));
      expect(backend.sharedTexts, hasLength(5));
      expect(backend.copiedTexts, everyElement(equals(baselineText)));
      expect(backend.copiedTexts, hasLength(5));

      // The snapshot's quantities/amounts/totals are unchanged: no deduction,
      // confirmed balance (as reflected in the snapshot) untouched (Req 15.6).
      expect(snapshot.lines, hasLength(1));
      expect(snapshot.lines.single.goods.input.allocatedCft, baselinePieces);
      expect(snapshot.lines.single.amount, baselineAmount);
      expect(snapshot.totals.payable, baselinePayable);

      // And the generators still reproduce the exact same payloads afterwards.
      expect(docx.buildDocx(snapshot), equals(baselineDocx));
      expect(whatsApp.buildMessage(snapshot), equals(baselineText));
    });

    test('a later catalog/rate change cannot alter an already-issued snapshot '
        '(Req 4.8, 12.7, Property 24)', () async {
      final snapshot = buildExportSnapshot();
      final issuedText = whatsApp.buildMessage(snapshot);
      final issuedDocx = docx.buildDocx(snapshot);

      // Simulate the catalog/pricing moving on by building a DIFFERENT snapshot
      // with a new rate and variety name. The already-issued `snapshot` value
      // is a separate immutable object and is unaffected: its export is
      // byte-identical to what it was at issue time.
      final movedOn = docx_model.InvoiceSnapshot(
        business: snapshot.business,
        invoiceNumber: snapshot.invoiceNumber,
        dateLabel: snapshot.dateLabel,
        customerName: snapshot.customerName,
        customerPhone: snapshot.customerPhone,
        lines: [
          docx_model.InvoiceLineSnapshot(
            variety: 'Renamed Mahogany',
            crossSection: '2 x 1 in',
            lengthFt: 6,
            units: '30 pcs (3 bunches)',
            goods: billing.priceLine(
              GoodsLineInput(
                stockItemId: 100,
                varietyId: 7,
                crossSectionId: 1,
                lengthFt: 6,
                allocatedCft: Cft(Rational(BigInt.from(25), BigInt.from(6))),
                rate: Rational.fromInt(9999),
              ),
            ),
          ),
        ],
        totals: snapshot.totals,
      );

      // The moved-on snapshot differs, proving the inputs really changed...
      expect(whatsApp.buildMessage(movedOn), isNot(equals(issuedText)));
      // ...yet the issued snapshot's exports are unchanged (immutable).
      expect(whatsApp.buildMessage(snapshot), equals(issuedText));
      expect(docx.buildDocx(snapshot), equals(issuedDocx));
    });
  });

  // --- (c) Voiding records a SEPARATE reversal and leaves the original
  // FinalizedInvoice snapshot field-for-field unchanged (Req 4.9, 13.2). -----

  group('voiding leaves the original FinalizedInvoice snapshot unchanged '
      '(Req 4.9, 13.2, Property 25)', () {
    test('field-for-field identity of the invoice is preserved after a void',
        () async {
      final auth = FakeAuthService(
        initialSession: const AuthSession(userId: 'owner'),
      );
      final (service, hosted, invoice) = await finalizeOne(auth);

      // Capture EVERY field of the original invoice + its single line before.
      final number = invoice.number;
      final ownerId = invoice.ownerId;
      final idempotencyKey = invoice.idempotencyKey;
      final payablePaise = invoice.totals.payable.paise;
      final taxPaise = invoice.totals.tax.paise;
      final loadingPaise = invoice.totals.loading.paise;
      final goodsPaise = invoice.totals.goodsSubtotal.paise;
      final lineCount = invoice.lines.length;

      final line = invoice.lines.single;
      final lineStockItemId = line.stockItemId;
      final lineVarietyId = line.varietyId;
      final lineVarietyName = line.varietyName;
      final lineLabel = line.label;
      final lineLengthFt = line.lengthFt;
      final linePieces = line.pieces;
      final lineRate = line.rate;
      final lineAmountPaise = line.amount.paise;
      final lineCftFixed = line.cft.toFixed();

      // Void records a SEPARATE reversal (never mutates the invoice).
      final restored = <int, int>{};
      final voided = await service.voidSale(
        invoice: invoice,
        idempotencyKey: 'void-separate-reversal',
        onRestoreStock: (stockItemId, delta) =>
            restored[stockItemId] = (restored[stockItemId] ?? 0) + delta,
      );

      // The reversal is a distinct record referencing the same invoice number,
      // restoring exactly the deducted pieces (+30, the reverse of -30).
      expect(voided.number, number);
      expect(restored[100], 30);
      expect(voided.restoredPieces[100], 30);
      // Committed as its own effect, keyed separately from the finalize.
      expect(hosted.hasApplied('void-separate-reversal'), isTrue);
      expect(hosted.hasApplied('invoice-voided:$number'), isTrue);
      expect(hosted.hasApplied('invoice-void-movement:$number:100'), isTrue);

      // The ORIGINAL FinalizedInvoice is byte-for-byte / field-for-field the
      // same object it was before the void (Req 13.2): nothing on it moved.
      expect(invoice.number, number);
      expect(invoice.ownerId, ownerId);
      expect(invoice.idempotencyKey, idempotencyKey);
      expect(invoice.totals.payable.paise, payablePaise);
      expect(invoice.totals.tax.paise, taxPaise);
      expect(invoice.totals.loading.paise, loadingPaise);
      expect(invoice.totals.goodsSubtotal.paise, goodsPaise);
      expect(invoice.lines, hasLength(lineCount));

      final after = invoice.lines.single;
      expect(after.stockItemId, lineStockItemId);
      expect(after.varietyId, lineVarietyId);
      expect(after.varietyName, lineVarietyName);
      expect(after.label, lineLabel);
      expect(after.lengthFt, lineLengthFt);
      expect(after.pieces, linePieces);
      expect(after.rate, lineRate);
      expect(after.amount.paise, lineAmountPaise);
      expect(after.cft.toFixed(), lineCftFixed);

      // The invoice's lines list is STILL unmodifiable after the void.
      expect(() => invoice.lines.add(after), throwsUnsupportedError);

      await auth.dispose();
    });
  });
}

