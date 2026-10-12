/// Genuine OOXML `.docx` generation from a finalized invoice snapshot
/// (task 12.1).
///
/// `DocxExportService` turns an immutable [InvoiceSnapshot] — the same persisted
/// value the on-screen preview and the WhatsApp text consume — into a **real**
/// Word document: a ZIP package of OOXML parts, not a renamed text/HTML file
/// and not a PDF (Requirement 14.1, 14.2). Because every surface reads the one
/// snapshot, the Word document values match the preview exactly (Requirement
/// 14.3).
///
/// The produced package contains, at minimum, the two parts that make a ZIP a
/// valid Word document (Requirement 14.1; verification 21.24):
///   * `[Content_Types].xml` — declares the content types of the parts, and
///   * `word/document.xml` — the WordprocessingML body.
/// It also writes the `_rels/.rels` and `word/_rels/document.xml.rels`
/// relationship parts a conformant consumer expects, so the file opens as an
/// editable document rather than a repair-prompt.
///
/// The document body carries the four blocks Requirement 14.4 requires — a
/// business header, an invoice-and-customer block, an item table, and the
/// totals — and the header block is emitted as a WordprocessingML page header
/// (`word/header1.xml`) referenced by the section, so it **repeats on every
/// page** of a multi-page invoice (Requirement 14.5). The simple-sales-bill vs
/// tax-invoice title is taken from the shared [BillKind] rule so a preview and
/// its export can never disagree about the document kind
/// (`bill_presentation.dart`).
///
/// `buildFileName` produces a human-readable name such as
/// `Invoice_INV-21_Ramesh_Timber.docx` (Requirement 14.6). Sharing/export via
/// the iOS share sheet (14.7) and never-re-deducting stock on share (15.6) are
/// the wiring task 12.3's concern; this service is a pure value→bytes function
/// and performs no I/O, so it runs headless under `flutter test` on Windows.
///
/// Architecture note: this service lives in the application layer and depends
/// only on the pure domain types, the goods/totals values from
/// `billing_service.dart`, and `package:archive` for ZIP packaging. It does not
/// import `package:flutter/*` and does not touch the hosted database (the DB is
/// mocked by `FakeHostedDatabase`; this operates on the in-memory snapshot
/// only).
library;

import 'package:archive/archive.dart';
import 'package:meta/meta.dart';

import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/domain/bill_presentation.dart';
import 'package:wood_cft/domain/business_settings.dart';
import 'package:wood_cft/domain/cft.dart';
import 'package:wood_cft/domain/money.dart';

/// One immutable line of a finalized invoice snapshot, carrying the snapshotted
/// descriptive keys and the priced goods line.
///
/// The descriptive fields ([variety], [crossSection], [lengthFt], [units]) are
/// snapshotted strings/ints taken at finalize time so the export never
/// re-derives them from the mutable catalog. [goods] is the already-priced
/// [GoodsLine] from `billing_service.dart`, so the exact CFT, rate, and rounded
/// amount shown here are the same values the preview computed.
@immutable
class InvoiceLineSnapshot {
  /// Creates an invoice line snapshot.
  const InvoiceLineSnapshot({
    required this.variety,
    required this.crossSection,
    required this.lengthFt,
    required this.units,
    required this.goods,
  });

  /// The snapshotted variety name (e.g. `Mahogany`).
  final String variety;

  /// The snapshotted cross-section label (e.g. `2 x 1 in`).
  final String crossSection;

  /// The piece length in feet.
  final int lengthFt;

  /// A human-readable unit count for the line (e.g. `30 pcs (3 bunches)`).
  final String units;

  /// The priced goods line (exact CFT, exact rate, rounded amount).
  final GoodsLine goods;

  /// The exact allocated volume for this line.
  Cft get cft => goods.input.allocatedCft;

  /// The rounded line amount.
  Money get amount => goods.amount;
}

/// The complete, immutable finalized-invoice snapshot the exports render.
///
/// This is the single in-memory value the DOCX export, the preview, and the
/// WhatsApp text all consume (Requirement 14.3, 15.3). It bundles the business
/// identity ([business]), the invoice/customer identity, the priced [lines],
/// and the computed [totals] from `billing_service.dart`. The [kind] is derived
/// once via the shared [BillPresentation.classify] rule so the document title
/// is honest about whether it is a tax invoice or a simple sales bill.
@immutable
class InvoiceSnapshot {
  /// Creates an invoice snapshot.
  const InvoiceSnapshot({
    required this.business,
    required this.invoiceNumber,
    required this.dateLabel,
    required this.customerName,
    this.customerPhone = '',
    required this.lines,
    required this.totals,
  });

  /// The business identity (name, address, phone, GSTIN, prefix).
  final BusinessProfile business;

  /// The permanent invoice number assigned at finalize (e.g. `INV-21`).
  final String invoiceNumber;

  /// A pre-formatted invoice date label (e.g. `21-05-2024`).
  final String dateLabel;

  /// The customer name.
  final String customerName;

  /// The customer phone (optional; empty when none was recorded).
  final String customerPhone;

  /// The priced lines, in display order.
  final List<InvoiceLineSnapshot> lines;

  /// The computed invoice totals (goods subtotal, tax, loading, payable).
  final InvoiceTotals totals;

  /// The document kind derived from the business profile via the shared rule.
  ///
  /// A verified compliant tax invoice only when the statutory fields are
  /// complete; otherwise a simple sales bill (Requirement 18.6).
  BillKind get kind => BillPresentation.classify(business);
}

/// Pure value→bytes generator for the OOXML `.docx` export (task 12.1).
///
/// Stateless; a single `const` instance can be shared. [buildDocx] returns the
/// ZIP bytes of a valid Word document; [buildFileName] returns the
/// human-readable filename to attach it under.
class DocxExportService {
  /// Creates the DOCX export service.
  const DocxExportService();

  /// Builds the OOXML `.docx` package bytes for [snapshot].
  ///
  /// The returned bytes are a ZIP archive containing `[Content_Types].xml`,
  /// `_rels/.rels`, `word/_rels/document.xml.rels`, `word/header1.xml`, and
  /// `word/document.xml` (Requirement 14.1). The document body carries the
  /// business header, invoice-and-customer block, item table, and totals
  /// (14.4), and the header part is referenced by the section so it repeats on
  /// every page (14.5).
  List<int> buildDocx(InvoiceSnapshot snapshot) {
    final archive = Archive()
      ..addFile(_part('[Content_Types].xml', _contentTypesXml()))
      ..addFile(_part('_rels/.rels', _rootRelsXml()))
      ..addFile(
        _part('word/_rels/document.xml.rels', _documentRelsXml()),
      )
      ..addFile(_part('word/header1.xml', _headerXml(snapshot)))
      ..addFile(_part('word/document.xml', _documentXml(snapshot)));

    // Store-encode is sufficient and keeps the package deterministic; a Word
    // consumer accepts stored (uncompressed) ZIP entries.
    final zipped = ZipEncoder().encode(archive);
    return zipped;
  }

  /// Builds a human-readable filename for [snapshot] (Requirement 14.6).
  ///
  /// Shape: `Invoice_<number>_<customer>.docx`, with the number and customer
  /// sanitised to filesystem-safe characters. Falls back to `Invoice` /
  /// `Customer` when a part is blank so the name is never empty or dangling.
  String buildFileName(InvoiceSnapshot snapshot) {
    final number = _slug(snapshot.invoiceNumber, fallback: 'Invoice');
    final customer = _slug(snapshot.customerName, fallback: 'Customer');
    return 'Invoice_${number}_$customer.docx';
  }

  // --- OOXML part builders -------------------------------------------------

  ArchiveFile _part(String name, String xml) => ArchiveFile.string(name, xml);

  String _contentTypesXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '<Override PartName="/word/header1.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>'
        '</Types>';
  }

  String _rootRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
        'Target="word/document.xml"/>'
        '</Relationships>';
  }

  String _documentRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" '
        'Target="header1.xml"/>'
        '</Relationships>';
  }

  /// The page-header part, repeated on every page (Requirement 14.5). Carries
  /// the business identity block.
  String _headerXml(InvoiceSnapshot snapshot) {
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write(
        '<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">',
      );
    for (final line in _businessHeaderLines(snapshot)) {
      b.write(_paragraph(line.text, bold: line.bold));
    }
    b.write('</w:hdr>');
    return b.toString();
  }

  String _documentXml(InvoiceSnapshot snapshot) {
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write(
        '<w:document '
        'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
      )
      ..write('<w:body>');

    // Also render the business header once in the body flow so a reader that
    // ignores page headers (and the unzip assertions) still sees the identity.
    for (final line in _businessHeaderLines(snapshot)) {
      b.write(_paragraph(line.text, bold: line.bold));
    }

    // Document title: Tax Invoice vs Sales Bill (shared BillKind rule).
    b
      ..write(_paragraph(snapshot.kind.label, bold: true))
      ..write(_paragraph(''));

    // Invoice-and-customer block (Requirement 14.4).
    b
      ..write(_paragraph('Invoice: ${snapshot.invoiceNumber}'))
      ..write(_paragraph('Date: ${snapshot.dateLabel}'));
    final customer = snapshot.customerPhone.trim().isEmpty
        ? 'Customer: ${snapshot.customerName}'
        : 'Customer: ${snapshot.customerName}  ${snapshot.customerPhone}';
    b
      ..write(_paragraph(customer))
      ..write(_paragraph(''));

    // Item table (Requirement 14.4).
    b.write(_itemTable(snapshot));

    // Totals block (Requirement 14.4).
    final t = snapshot.totals;
    b
      ..write(_paragraph(''))
      ..write(_paragraph('Goods subtotal: ${t.goodsSubtotal.format()}'))
      ..write(_paragraph('Tax (${t.taxLabel}): ${t.tax.format()}'))
      ..write(_paragraph('Loading: ${t.loading.format()}'))
      ..write(_paragraph('Payable: ${t.payable.format()}', bold: true));

    // Section properties referencing the repeated page header (Requirement
    // 14.5).
    b
      ..write('<w:sectPr>')
      ..write('<w:headerReference w:type="default" r:id="rId1"/>')
      ..write(
        '<w:pgSz w:w="11906" w:h="16838"/>',
      )
      ..write(
        '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" '
        'w:header="708" w:footer="708" w:gutter="0"/>',
      )
      ..write('</w:sectPr>');

    b
      ..write('</w:body>')
      ..write('</w:document>');
    return b.toString();
  }

  /// The item-table WordprocessingML: a header row plus one row per line.
  String _itemTable(InvoiceSnapshot snapshot) {
    final b = StringBuffer()
      ..write('<w:tbl>')
      ..write(
        '<w:tblPr>'
        '<w:tblW w:w="0" w:type="auto"/>'
        '<w:tblBorders>'
        '<w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
        '<w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
        '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
        '<w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
        '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
        '<w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
        '</w:tblBorders>'
        '</w:tblPr>',
      )
      ..write(
        _tableRow(
          const [
            'Variety',
            'Cross-section',
            'Length (ft)',
            'Units',
            'CFT',
            'Rate (₹/CFT)',
            'Amount',
          ],
          bold: true,
        ),
      );

    for (final line in snapshot.lines) {
      b.write(
        _tableRow([
          line.variety,
          line.crossSection,
          '${line.lengthFt}',
          line.units,
          line.cft.toFixed(),
          '\u20B9${line.goods.input.rate.toDouble().toStringAsFixed(2)}',
          line.amount.format(),
        ]),
      );
    }

    b.write('</w:tbl>');
    return b.toString();
  }

  String _tableRow(List<String> cells, {bool bold = false}) {
    final b = StringBuffer()..write('<w:tr>');
    for (final cell in cells) {
      b
        ..write('<w:tc>')
        ..write('<w:tcPr><w:tcW w:w="0" w:type="auto"/></w:tcPr>')
        ..write(_paragraph(cell, bold: bold))
        ..write('</w:tc>');
    }
    b.write('</w:tr>');
    return b.toString();
  }

  /// A single WordprocessingML paragraph with [text], optionally [bold].
  String _paragraph(String text, {bool bold = false}) {
    final runProps = bold ? '<w:rPr><w:b/></w:rPr>' : '';
    return '<w:p><w:r>$runProps'
        '<w:t xml:space="preserve">${_xmlEscape(text)}</w:t>'
        '</w:r></w:p>';
  }

  List<_HeaderLine> _businessHeaderLines(InvoiceSnapshot snapshot) {
    final profile = snapshot.business;
    final name = profile.name.trim().isEmpty ? 'Sales Bill' : profile.name;
    final lines = <_HeaderLine>[_HeaderLine(name, bold: true)];
    if (profile.address.trim().isNotEmpty) {
      lines.add(_HeaderLine(profile.address));
    }
    final contactParts = <String>[
      if (profile.phone.trim().isNotEmpty) 'Ph: ${profile.phone}',
      if ((profile.gstin ?? '').trim().isNotEmpty) 'GSTIN: ${profile.gstin}',
    ];
    if (contactParts.isNotEmpty) {
      lines.add(_HeaderLine(contactParts.join('  |  ')));
    }
    return lines;
  }

  // --- helpers -------------------------------------------------------------

  static String _xmlEscape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  /// Reduces [value] to a filesystem-safe slug, falling back to [fallback]
  /// when the result would be empty.
  static String _slug(String value, {required String fallback}) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? fallback : cleaned;
  }
}

/// A single header text line and whether it is bold. Internal helper.
@immutable
class _HeaderLine {
  const _HeaderLine(this.text, {this.bold = false});

  final String text;
  final bool bold;
}
