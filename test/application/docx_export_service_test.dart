// Pure-Dart unit tests for the OOXML DOCX export (task 12.1).
//
// These pin the automatable part of Requirement 14 (and verification 21.24):
//   * buildDocx returns a genuine ZIP package (not a renamed text/HTML/PDF)
//     whose entries include at least `[Content_Types].xml` and
//     `word/document.xml` (Req 14.1, 14.2);
//   * the document body carries the business header, the invoice-and-customer
//     block, an item table, and the totals, with values matching the snapshot
//     exactly (Req 14.3, 14.4);
//   * the page-header part is present and referenced by the section so it
//     repeats on each page (Req 14.5);
//   * the simple-sales-bill vs tax-invoice title follows the shared BillKind
//     rule (Req 18.6); and
//   * buildFileName is human-readable (Req 14.6).
//
// The output is unzipped with the same `archive` package used to build it and
// the required OOXML parts are asserted directly. No widgets are pumped and no
// database is touched — the service is a pure value→bytes function operating on
// the in-memory snapshot (the hosted DB is mocked by FakeHostedDatabase).

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/application/docx_export_service.dart';
import 'package:wood_cft/domain/bill_presentation.dart';
import 'package:wood_cft/domain/business_settings.dart';
import 'package:wood_cft/domain/cft.dart';

void main() {
  const service = DocxExportService();
  const billing = BillingService();

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

  InvoiceSnapshot buildSnapshot({
    BusinessProfile? business,
    String invoiceNumber = 'INV-21',
    String customerName = 'Ramesh Timber',
    String customerPhone = '9876543210',
  }) {
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
      business: business ??
          const BusinessProfile(
            name: 'Wood CFT Timbers',
            address: '12 Mill Road, Chennai',
            phone: '044-12345',
            gstin: '33ABCDE1234F1Z5',
            invoicePrefix: 'INV-',
          ),
      invoiceNumber: invoiceNumber,
      dateLabel: '21-05-2024',
      customerName: customerName,
      customerPhone: customerPhone,
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

  // Unzips the built docx and returns part-name -> utf8 string content.
  Map<String, String> unzip(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    return {
      for (final f in archive.files)
        if (f.isFile) f.name: utf8.decode(f.content),
    };
  }

  group('valid OOXML package (Req 14.1, 14.2, 21.24)', () {
    test('output unzips to a ZIP containing the required OOXML parts', () {
      final bytes = service.buildDocx(buildSnapshot());

      // Genuine ZIP: local-file-header magic "PK\x03\x04".
      expect(bytes.sublist(0, 4), [0x50, 0x4B, 0x03, 0x04]);

      final parts = unzip(bytes);
      expect(parts.keys, contains('[Content_Types].xml'));
      expect(parts.keys, contains('word/document.xml'));
      // Relationship + header parts for a conformant, openable document.
      expect(parts.keys, contains('_rels/.rels'));
      expect(parts.keys, contains('word/_rels/document.xml.rels'));
      expect(parts.keys, contains('word/header1.xml'));
    });

    test('content types declare the main document and header parts', () {
      final parts = unzip(service.buildDocx(buildSnapshot()));
      final contentTypes = parts['[Content_Types].xml']!;
      expect(
        contentTypes,
        contains('wordprocessingml.document.main+xml'),
      );
      expect(contentTypes, contains('wordprocessingml.header+xml'));
    });

    test('document.xml is WordprocessingML, not text/HTML/PDF', () {
      final parts = unzip(service.buildDocx(buildSnapshot()));
      final doc = parts['word/document.xml']!;
      expect(doc, startsWith('<?xml'));
      expect(doc, contains('<w:document'));
      expect(doc, contains('<w:body>'));
      // Never a PDF: no %PDF marker anywhere in the package.
      expect(doc, isNot(contains('%PDF')));
    });
  });

  group('document content matches the snapshot (Req 14.3, 14.4)', () {
    test('business header, invoice/customer block, and totals are present', () {
      final snapshot = buildSnapshot();
      final parts = unzip(service.buildDocx(snapshot));
      final doc = parts['word/document.xml']!;

      // Business header (also repeated in header1.xml).
      expect(doc, contains('Wood CFT Timbers'));
      expect(doc, contains('12 Mill Road, Chennai'));

      // Invoice-and-customer block.
      expect(doc, contains('Invoice: INV-21'));
      expect(doc, contains('Date: 21-05-2024'));
      expect(doc, contains('Ramesh Timber'));
      expect(doc, contains('9876543210'));

      // Totals (exact formatted values from the snapshot).
      expect(doc, contains(snapshot.totals.goodsSubtotal.format()));
      expect(doc, contains(snapshot.totals.tax.format()));
      expect(doc, contains(snapshot.totals.loading.format()));
      expect(doc, contains(snapshot.totals.payable.format()));
    });

    test('item table carries each line with CFT and amount', () {
      final snapshot = buildSnapshot();
      final parts = unzip(service.buildDocx(snapshot));
      final doc = parts['word/document.xml']!;

      // Table structure present.
      expect(doc, contains('<w:tbl>'));
      // Column headers.
      expect(doc, contains('Variety'));
      expect(doc, contains('Cross-section'));
      expect(doc, contains('Amount'));

      for (final line in snapshot.lines) {
        expect(doc, contains(line.variety));
        expect(doc, contains(line.crossSection));
        expect(doc, contains(line.cft.toFixed()));
        expect(doc, contains(line.amount.format()));
      }
    });
  });

  group('repeated page header (Req 14.5)', () {
    test('header part exists and section references it', () {
      final parts = unzip(service.buildDocx(buildSnapshot()));
      expect(parts['word/header1.xml'], contains('<w:hdr'));
      expect(parts['word/header1.xml'], contains('Wood CFT Timbers'));

      final doc = parts['word/document.xml']!;
      expect(doc, contains('<w:sectPr>'));
      expect(doc, contains('<w:headerReference'));
    });
  });

  group('bill kind title (Req 18.6)', () {
    test('complete statutory fields -> Tax Invoice title', () {
      final snapshot = buildSnapshot();
      expect(snapshot.kind, BillKind.taxInvoice);
      final doc = unzip(service.buildDocx(snapshot))['word/document.xml']!;
      expect(doc, contains('Tax Invoice'));
    });

    test('empty profile -> Sales Bill title (never fabricated)', () {
      final snapshot = buildSnapshot(business: BusinessProfile.empty);
      expect(snapshot.kind, BillKind.simpleSalesBill);
      final doc = unzip(service.buildDocx(snapshot))['word/document.xml']!;
      expect(doc, contains('Sales Bill'));
      expect(doc, isNot(contains('Tax Invoice')));
    });
  });

  group('filename (Req 14.6)', () {
    test('human-readable Invoice_<number>_<customer>.docx', () {
      final name = service.buildFileName(buildSnapshot());
      expect(name, 'Invoice_INV-21_Ramesh_Timber.docx');
    });

    test('sanitises unsafe characters and falls back on blanks', () {
      final name = service.buildFileName(
        buildSnapshot(invoiceNumber: '  ', customerName: 'A/B:C*'),
      );
      expect(name, endsWith('.docx'));
      expect(name, startsWith('Invoice_Invoice_'));
      // No path-separator or illegal filename characters leaked through.
      expect(name, isNot(contains('/')));
      expect(name, isNot(contains(':')));
      expect(name, isNot(contains('*')));
    });
  });
}
