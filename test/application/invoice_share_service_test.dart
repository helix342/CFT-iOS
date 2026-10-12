// Headless unit tests for the invoice share/copy coordinator (task 12.3).
//
// These pin the automatable part of Requirement 15.4-15.7 over an injectable
// fake backend (no iPhone, no share sheet, no real clipboard):
//   * Share invoice file hands the DOCX bytes + human-readable filename to the
//     share sheet (Req 15.4, 14.6, 14.7);
//   * Share bill text hands the WhatsApp message to the share sheet (Req 15.4,
//     15.5);
//   * Copy bill text hands the WhatsApp message to the clipboard (Req 15.4);
//   * none of the three actions mutate the finalized snapshot or trigger any
//     stock/billing work (Req 15.6, snapshot immutability); and
//   * PDF is an optional extra only: unavailable by default (throws), and when
//     an exporter is injected it is purely additive and never replaces the
//     DOCX/WhatsApp exports (Req 15.7).
//
// The payload values are cross-checked against the pure generators so the
// coordinator is proven to be a faithful pass-through, not a re-computation.

import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/application/docx_export_service.dart';
import 'package:wood_cft/application/invoice_share_service.dart';
import 'package:wood_cft/application/whatsapp_export_service.dart';
import 'package:wood_cft/domain/business_settings.dart';
import 'package:wood_cft/domain/cft.dart';

void main() {
  const billing = BillingService();
  const docx = DocxExportService();
  const whatsApp = WhatsAppExportService();

  GoodsLine priceLine({
    required Cft cft,
    required Rational rate,
    int lengthFt = 6,
  }) {
    return billing.priceLine(
      GoodsLineInput(
        stockItemId: 1,
        varietyId: 1,
        crossSectionId: 1,
        lengthFt: lengthFt,
        allocatedCft: cft,
        rate: rate,
      ),
    );
  }

  InvoiceSnapshot buildSnapshot() {
    final line1 = priceLine(
      cft: Cft(Rational(BigInt.from(25), BigInt.from(6))),
      rate: Rational.fromInt(400),
    );
    final line2 = priceLine(
      cft: Cft.fromInt(2),
      rate: Rational.fromInt(1000),
      lengthFt: 8,
    );
    final goods = billing.computeGoods([line1.input, line2.input]);
    final totals = billing.computeTotals(goods, TaxMode.eighteen);

    return InvoiceSnapshot(
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
        InvoiceLineSnapshot(
          variety: 'Mahogany',
          crossSection: '2 x 1 in',
          lengthFt: 6,
          units: '30 pcs (3 bunches)',
          goods: line1,
        ),
        InvoiceLineSnapshot(
          variety: 'Teak',
          crossSection: '3 x 1 in',
          lengthFt: 8,
          units: '12 pcs',
          goods: line2,
        ),
      ],
      totals: totals,
    );
  }

  group('Share invoice file (Req 15.4, 14.6, 14.7)', () {
    test('passes the DOCX bytes and filename to the share sheet', () async {
      final backend = FakeShareBackend();
      final service = InvoiceShareService(backend: backend);
      final snapshot = buildSnapshot();

      await service.shareInvoiceFile(snapshot);

      expect(backend.sharedFiles, hasLength(1));
      final payload = backend.sharedFiles.single;

      // The bytes are exactly the DOCX export's bytes (faithful pass-through).
      expect(payload.bytes, equals(docx.buildDocx(snapshot)));
      // The filename is the human-readable DOCX name (Req 14.6).
      expect(payload.fileName, equals(docx.buildFileName(snapshot)));
      expect(payload.fileName, equals('Invoice_INV-21_Ramesh_Timber.docx'));
      // Advertised as a Word document, never a PDF (Req 14.2).
      expect(payload.mimeType, equals(InvoiceShareService.docxMimeType));
      expect(payload.mimeType, isNot(contains('pdf')));

      // No text/clipboard side effects from a file share.
      expect(backend.sharedTexts, isEmpty);
      expect(backend.copiedTexts, isEmpty);
    });
  });

  group('Share bill text (Req 15.4, 15.5)', () {
    test('passes the WhatsApp message to the share sheet', () async {
      final backend = FakeShareBackend();
      final service = InvoiceShareService(backend: backend);
      final snapshot = buildSnapshot();

      await service.shareBillText(snapshot);

      expect(backend.sharedTexts, hasLength(1));
      // Exactly the WhatsApp generator's output (faithful pass-through).
      expect(backend.sharedTexts.single, equals(whatsApp.buildMessage(snapshot)));

      expect(backend.sharedFiles, isEmpty);
      expect(backend.copiedTexts, isEmpty);
    });
  });

  group('Copy bill text (Req 15.4)', () {
    test('passes the WhatsApp message to the clipboard', () async {
      final backend = FakeShareBackend();
      final service = InvoiceShareService(backend: backend);
      final snapshot = buildSnapshot();

      await service.copyBillText(snapshot);

      expect(backend.copiedTexts, hasLength(1));
      expect(backend.copiedTexts.single, equals(whatsApp.buildMessage(snapshot)));

      expect(backend.sharedFiles, isEmpty);
      expect(backend.sharedTexts, isEmpty);
    });
  });

  group('Sharing never mutates the snapshot (Req 15.6)', () {
    test('all three actions leave the snapshot and its payloads unchanged',
        () async {
      final backend = FakeShareBackend();
      final service = InvoiceShareService(backend: backend);
      final snapshot = buildSnapshot();

      // Capture the expected payloads before any action runs.
      final expectedDocx = docx.buildDocx(snapshot);
      final expectedFileName = docx.buildFileName(snapshot);
      final expectedText = whatsApp.buildMessage(snapshot);

      // Run every action twice; a re-deduct or mutation would change outputs.
      await service.shareInvoiceFile(snapshot);
      await service.shareBillText(snapshot);
      await service.copyBillText(snapshot);
      await service.shareInvoiceFile(snapshot);
      await service.shareBillText(snapshot);
      await service.copyBillText(snapshot);

      // Repeated shares produce byte-identical / text-identical payloads: the
      // snapshot is immutable and no stock/billing recomputation occurred.
      expect(backend.sharedFiles, hasLength(2));
      expect(backend.sharedFiles[0].bytes, equals(expectedDocx));
      expect(backend.sharedFiles[1].bytes, equals(expectedDocx));
      expect(backend.sharedFiles[0].fileName, equals(expectedFileName));
      expect(backend.sharedFiles[1].fileName, equals(expectedFileName));

      expect(backend.sharedTexts, equals([expectedText, expectedText]));
      expect(backend.copiedTexts, equals([expectedText, expectedText]));

      // The snapshot still regenerates the exact same payloads afterwards.
      expect(docx.buildDocx(snapshot), equals(expectedDocx));
      expect(whatsApp.buildMessage(snapshot), equals(expectedText));
    });
  });

  group('PDF is an optional extra only (Req 15.7)', () {
    test('unavailable by default and throws rather than replacing DOCX',
        () async {
      final backend = FakeShareBackend();
      final service = InvoiceShareService(backend: backend);
      final snapshot = buildSnapshot();

      expect(service.isPdfAvailable, isFalse);
      await expectLater(
        () => service.sharePdfFile(snapshot),
        throwsStateError,
      );
      // DOCX and WhatsApp actions remain fully available.
      await service.shareInvoiceFile(snapshot);
      await service.shareBillText(snapshot);
      expect(backend.sharedFiles, hasLength(1));
      expect(backend.sharedTexts, hasLength(1));
    });

    test('is additive when an exporter is injected (never replaces DOCX)',
        () async {
      final backend = FakeShareBackend();
      final service = InvoiceShareService(
        backend: backend,
        pdfExporter: const _FakePdfExporter(),
      );
      final snapshot = buildSnapshot();

      expect(service.isPdfAvailable, isTrue);

      // DOCX export still works and is still the Word MIME type.
      await service.shareInvoiceFile(snapshot);
      // PDF is an extra, additional share.
      await service.sharePdfFile(snapshot);

      expect(backend.sharedFiles, hasLength(2));
      expect(
        backend.sharedFiles[0].mimeType,
        equals(InvoiceShareService.docxMimeType),
      );
      expect(
        backend.sharedFiles[1].mimeType,
        equals(InvoiceShareService.pdfMimeType),
      );
      // The DOCX bytes are untouched by the optional PDF path.
      expect(backend.sharedFiles[0].bytes, equals(docx.buildDocx(snapshot)));
    });
  });
}

/// Minimal [PdfExporter] used only to prove the optional PDF seam is additive.
class _FakePdfExporter implements PdfExporter {
  const _FakePdfExporter();

  @override
  List<int> buildPdf(InvoiceSnapshot snapshot) => const [37, 80, 68, 70]; // %PDF

  @override
  String buildFileName(InvoiceSnapshot snapshot) =>
      'Invoice_${snapshot.invoiceNumber}.pdf';
}
