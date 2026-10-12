// Pure-Dart unit tests for the WhatsApp text export (task 12.2).
//
// These pin the automatable part of Requirement 15:
//   * buildMessage produces human-readable formatted text from the same
//     snapshot the preview and DOCX consume (Req 15.1);
//   * the text uses simple headings, line breaks, and WhatsApp *bold* emphasis
//     and contains NO Markdown-table syntax (Req 15.2);
//   * every money/CFT value equals the snapshot's formatted value, matching the
//     DOCX export exactly (Req 15.3); and
//   * the simple-sales-bill vs tax-invoice title follows the shared BillKind
//     rule (Req 18.6).
//
// No widgets are pumped and no database/clipboard/share sheet is touched — the
// service is a pure value→String function over the in-memory snapshot.

import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/application/docx_export_service.dart';
import 'package:wood_cft/application/whatsapp_export_service.dart';
import 'package:wood_cft/domain/bill_presentation.dart';
import 'package:wood_cft/domain/business_settings.dart';
import 'package:wood_cft/domain/cft.dart';

void main() {
  const service = WhatsAppExportService();
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

  group('content present (Req 15.1)', () {
    test('business header, invoice/customer block, and item lines present', () {
      final snapshot = buildSnapshot();
      final text = service.buildMessage(snapshot);

      // Business header (name emphasised with *bold*).
      expect(text, contains('*Wood CFT Timbers*'));
      expect(text, contains('12 Mill Road, Chennai'));
      expect(text, contains('Ph: 044-12345'));
      expect(text, contains('GSTIN: 33ABCDE1234F1Z5'));

      // Invoice-and-customer block.
      expect(text, contains('Invoice: INV-21'));
      expect(text, contains('Date: 21-05-2024'));
      expect(text, contains('Customer: Ramesh Timber'));
      expect(text, contains('9876543210'));

      // One line per item: variety, cross-section, length, units.
      expect(text, contains('Mahogany 2 x 1 in, 6 ft'));
      expect(text, contains('30 pcs (3 bunches)'));
      expect(text, contains('Teak 3 x 1 in, 8 ft'));
      expect(text, contains('12 pcs'));

      // Totals labels.
      expect(text, contains('Goods subtotal:'));
      expect(text, contains('Loading:'));
    });

    test('uses line breaks (headings on their own lines)', () {
      final text = service.buildMessage(buildSnapshot());
      final lines = text.split('\n');
      expect(lines.first, '*Wood CFT Timbers*');
      expect(lines, contains('Invoice: INV-21'));
    });
  });

  group('WhatsApp formatting, no Markdown tables (Req 15.2)', () {
    test('payable total is emphasised with *bold*', () {
      final snapshot = buildSnapshot();
      final text = service.buildMessage(snapshot);
      expect(text, contains('*Payable: ${snapshot.totals.payable.format()}*'));
    });

    test('contains no Markdown-table syntax', () {
      final text = service.buildMessage(buildSnapshot());
      // A Markdown table is defined by a pipe-delimited header *separator* row
      // of the form `|---|---|` (dashes between pipes). Items are rendered as
      // plain indented text, so no such row exists. The `  |  ` used as a
      // visual contact-line separator is not a table and is allowed.
      expect(text, isNot(contains('---|')));
      expect(text, isNot(contains('|---')));
      expect(text, isNot(matches(RegExp(r'\|\s*:?-{3,}:?\s*\|'))));
      for (final line in text.split('\n')) {
        // No line is a Markdown table separator row.
        expect(
          RegExp(r'^\s*\|?[\s:|-]*-{3,}[\s:|-]*\|').hasMatch(line),
          isFalse,
          reason: 'line looks like a Markdown table separator row: $line',
        );
      }
    });
  });

  group('values match the snapshot and DOCX (Req 15.3)', () {
    test('every money/CFT value equals the snapshot formatted value', () {
      final snapshot = buildSnapshot();
      final text = service.buildMessage(snapshot);

      for (final line in snapshot.lines) {
        expect(text, contains(line.cft.toFixed()));
        expect(text, contains(line.amount.format()));
      }
      expect(text, contains(snapshot.totals.goodsSubtotal.format()));
      expect(text, contains(snapshot.totals.tax.format()));
      expect(text, contains(snapshot.totals.loading.format()));
      expect(text, contains(snapshot.totals.payable.format()));
    });

    test('tax line carries the shared tax label', () {
      final snapshot = buildSnapshot();
      final text = service.buildMessage(snapshot);
      expect(
        text,
        contains('Tax (${snapshot.totals.taxLabel}): '
            '${snapshot.totals.tax.format()}'),
      );
    });

    test('line rate matches the DOCX rate rendering exactly', () {
      final snapshot = buildSnapshot();
      final whatsApp = service.buildMessage(snapshot);
      for (final line in snapshot.lines) {
        final rate =
            '\u20B9${line.goods.input.rate.toDouble().toStringAsFixed(2)}';
        expect(whatsApp, contains('@ $rate'));
      }
    });
  });

  group('bill kind title (Req 18.6)', () {
    test('complete statutory fields -> Tax Invoice title', () {
      final snapshot = buildSnapshot();
      expect(snapshot.kind, BillKind.taxInvoice);
      final text = service.buildMessage(snapshot);
      expect(text, contains('Tax Invoice'));
      expect(text, isNot(contains('Sales Bill')));
    });

    test('empty profile -> Sales Bill title (never fabricated)', () {
      final snapshot = buildSnapshot(business: BusinessProfile.empty);
      expect(snapshot.kind, BillKind.simpleSalesBill);
      final text = service.buildMessage(snapshot);
      expect(text, contains('Sales Bill'));
      expect(text, isNot(contains('Tax Invoice')));
    });
  });

  group('optional customer phone', () {
    test('customer line omits the phone when none was recorded', () {
      final snapshot = buildSnapshot(customerPhone: '');
      final text = service.buildMessage(snapshot);
      expect(text, contains('Customer: Ramesh Timber'));
      expect(text, isNot(contains('Customer: Ramesh Timber  ')));
    });
  });
}
