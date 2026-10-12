// Property-based tests for the invoice exports (task 12.4).
//
// This file pins the two export correctness properties from design.md ->
// Correctness Properties, driven over randomly generated finalized-invoice
// snapshots (>= 150 iterations each):
//
//   * Property 27 - Export outputs are consistent with the snapshot
//     (Requirements 14.3, 15.1, 15.3): for every snapshot, the WordprocessingML
//     DOCX body and the WhatsApp text present the SAME invoice figures. Every
//     line's exact CFT (`Cft.toFixed`) and rounded amount (`Money.format`), and
//     all four totals (goods subtotal, tax, loading, payable), appear in BOTH
//     surfaces and equal the values carried on the snapshot. Because both
//     exports read the one in-memory snapshot and format through the same
//     `Cft.toFixed` / `Money.format` helpers, a preview, a Word document, and a
//     WhatsApp message can never disagree about a figure.
//
//   * Property 28 - Exported DOCX is a valid OOXML package (Requirements 14.1,
//     14.2): for every snapshot, `buildDocx` returns a genuine ZIP (the
//     `PK\x03\x04` local-file-header magic bytes), and that archive always
//     contains the two parts that make a ZIP a Word document -
//     `[Content_Types].xml` and `word/document.xml` - and is NEVER a PDF (no
//     `%PDF` marker anywhere in the package). It is never a renamed text/HTML
//     file or a PDF.
//
// Snapshots are built from REAL priced goods lines: each line's exact CFT comes
// from the shared engine `CalculationService.lineCftFor` over random
// reaper/plank cross-sections, catalog lengths 2..9 ft, and whole quantities,
// priced at a random exact ₹/CFT rate through `BillingService`, and the totals
// come from `BillingService.computeTotals` under a random tax mode. So the
// properties speak to the values the billing engine actually produces, not to
// hand-picked figures.
//
// PBT framework: `package:glados`. `ExploreConfig(numRuns:, random:)` fixes the
// iteration count (>= 150) and seeds a deterministic `Random`, so any
// counterexample reproduces exactly. Glados re-exports `package:test`.
//
// Pure-Dart test: imports only the domain + application layers, `package:glados`,
// `package:archive`, and `package:rational`. No Flutter widgets, no IO, no
// database (the hosted DB is irrelevant here - the exports are pure
// value->bytes / value->String functions over the in-memory snapshot).

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:glados/glados.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/application/docx_export_service.dart';
import 'package:wood_cft/application/whatsapp_export_service.dart';
import 'package:wood_cft/domain/bill_presentation.dart';
import 'package:wood_cft/domain/business_settings.dart';
import 'package:wood_cft/domain/catalog.dart';

/// The shared engine and the services under test.
const CalculationService _calc = CalculationService();
const BillingService _billing = BillingService(_calc);
const DocxExportService _docx = DocxExportService();
const WhatsAppExportService _whatsApp = WhatsAppExportService();

/// Deterministic exploration config giving each property >= 150 iterations from
/// a fixed seed (so a failure reproduces exactly).
final ExploreConfig _explore =
    ExploreConfig(numRuns: 180, random: Random(20240612));

/// A randomly generated priced invoice line, constrained to the real input
/// space: a reaper/plank cross-section (width 1..12 in, thickness 1..6 in), a
/// catalog length 2..9 ft (Requirement 1.10), a whole quantity 1..300 pieces,
/// and a whole ₹/CFT rate 1..5000. Its exact CFT comes from the real engine.
class _Line {
  const _Line(
    this.widthIn,
    this.thicknessIn,
    this.isReaper,
    this.lengthFt,
    this.quantity,
    this.rateRupees,
  );

  final int widthIn;
  final int thicknessIn;
  final bool isReaper;
  final int lengthFt;
  final int quantity;
  final int rateRupees;

  CrossSection get crossSection => CrossSection(
        id: 1,
        widthIn: widthIn,
        thicknessIn: thicknessIn,
        category: isReaper ? WoodCategory.reaper : WoodCategory.plank,
      );

  Rational get rate => Rational.fromInt(rateRupees);

  GoodsLineInput get input => GoodsLineInput(
        stockItemId: 1,
        varietyId: 1,
        crossSectionId: 1,
        lengthFt: lengthFt,
        allocatedCft: _calc.lineCftFor(crossSection, lengthFt, quantity),
        rate: rate,
      );

  @override
  String toString() => '_Line(w: $widthIn, t: $thicknessIn, '
      'cat: ${isReaper ? 'reaper' : 'plank'}, l: $lengthFt, q: $quantity, '
      'rate: $rateRupees)';
}

/// A randomly generated snapshot specification: the priced lines, a tax-mode
/// selector (0 = No GST, 1 = 9%, 2 = 18%), and whether the business profile is
/// fully configured (so the document kind varies between tax invoice and simple
/// sales bill across runs).
class _SnapshotSpec {
  const _SnapshotSpec(this.lines, this.taxModeIndex, this.fullBusiness);

  final List<_Line> lines;
  final int taxModeIndex;
  final bool fullBusiness;

  TaxMode get taxMode => switch (taxModeIndex % 3) {
        0 => TaxMode.noGst,
        1 => TaxMode.nine,
        _ => TaxMode.eighteen,
      };

  BusinessProfile get business => fullBusiness
      ? const BusinessProfile(
          name: 'Wood CFT Timbers',
          address: '12 Mill Road, Chennai',
          phone: '044-12345',
          gstin: '33ABCDE1234F1Z5',
          invoicePrefix: 'INV-',
        )
      : BusinessProfile.empty;

  /// Builds the real [InvoiceSnapshot] for this spec using the actual billing
  /// engine, so every figure on it is one the engine computes.
  InvoiceSnapshot build() {
    final inputs = [for (final line in lines) line.input];
    final goods = _billing.computeGoods(inputs);
    final totals = _billing.computeTotals(goods, taxMode);

    final snapshotLines = <InvoiceLineSnapshot>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final cross = line.crossSection;
      final units = line.isReaper
          ? '${line.quantity} pcs (${line.quantity ~/ 10} bunches)'
          : '${line.quantity} pcs';
      snapshotLines.add(
        InvoiceLineSnapshot(
          variety: 'Variety$i',
          crossSection: cross.inchLabel,
          lengthFt: line.lengthFt,
          units: units,
          goods: goods.lines[i],
        ),
      );
    }

    return InvoiceSnapshot(
      business: business,
      invoiceNumber: 'INV-21',
      dateLabel: '21-05-2024',
      customerName: 'Ramesh Timber',
      customerPhone: '9876543210',
      lines: snapshotLines,
      totals: totals,
    );
  }

  @override
  String toString() => '_SnapshotSpec(lines: ${lines.length}, '
      'tax: ${taxMode.label}, fullBusiness: $fullBusiness)';
}

/// Generator for one valid priced line.
final Generator<_Line> _lineGen = any.combine6(
  any.intInRange(1, 13), // widthIn 1..12
  any.intInRange(1, 7), // thicknessIn 1..6
  any.bool, // reaper vs plank
  any.intInRange(2, 10), // lengthFt 2..9
  any.intInRange(1, 301), // quantity 1..300
  any.intInRange(1, 5001), // rate 1..5000 ₹/CFT
  _Line.new,
);

/// Generator for a snapshot spec: 1..12 priced lines (a finalized invoice has
/// at least one sold line), a tax-mode selector, and a business-completeness
/// flag.
final Generator<_SnapshotSpec> _specGen = any.combine3(
  any.listWithLengthInRange(1, 13, _lineGen),
  any.intInRange(0, 3),
  any.bool,
  _SnapshotSpec.new,
);

/// Unzips a built docx into a map of part-name -> utf8 string content.
Map<String, String> _unzip(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  return {
    for (final f in archive.files)
      if (f.isFile) f.name: utf8.decode(f.content),
  };
}

void main() {
  group('Export consistency + valid OOXML (task 12.4, glados)', () {
    Glados<_SnapshotSpec>(_specGen, _explore).test(
      'Feature: wood-cft-app, Property 27: Export outputs are consistent with '
      'the snapshot - the DOCX document and the WhatsApp text present the same '
      'per-line CFT and amount and the same four totals, all equal to the '
      'snapshot values (Requirements 14.3, 15.1, 15.3)',
      (_SnapshotSpec spec) {
        final snapshot = spec.build();

        final docParts = _unzip(_docx.buildDocx(snapshot));
        final docBody = docParts['word/document.xml']!;
        final whatsText = _whatsApp.buildMessage(snapshot);

        // Each line's exact CFT and rounded amount, as formatted on the
        // snapshot, appear in BOTH surfaces.
        for (var i = 0; i < snapshot.lines.length; i++) {
          final line = snapshot.lines[i];
          final cftText = line.cft.toFixed();
          final amountText = line.amount.format();

          expect(docBody, contains(cftText),
              reason: 'DOCX must carry line $i CFT $cftText');
          expect(whatsText, contains(cftText),
              reason: 'WhatsApp must carry line $i CFT $cftText');
          expect(docBody, contains(amountText),
              reason: 'DOCX must carry line $i amount $amountText');
          expect(whatsText, contains(amountText),
              reason: 'WhatsApp must carry line $i amount $amountText');
        }

        // All four totals, as formatted on the snapshot, appear in BOTH
        // surfaces (so the two exports agree on every total).
        final totals = snapshot.totals;
        for (final figure in <String>[
          totals.goodsSubtotal.format(),
          totals.tax.format(),
          totals.loading.format(),
          totals.payable.format(),
        ]) {
          expect(docBody, contains(figure),
              reason: 'DOCX must carry total $figure');
          expect(whatsText, contains(figure),
              reason: 'WhatsApp must carry total $figure');
        }

        // The document kind (Tax Invoice vs Sales Bill) is derived from the one
        // snapshot, so both surfaces agree on the title too.
        final kindLabel = snapshot.kind.label;
        expect(docBody, contains(kindLabel));
        expect(whatsText, contains(kindLabel));
      },
    );

    Glados<_SnapshotSpec>(_specGen, _explore).test(
      'Feature: wood-cft-app, Property 28: Exported DOCX is a valid OOXML '
      'package - buildDocx always returns a genuine ZIP containing '
      '[Content_Types].xml and word/document.xml and never a PDF '
      '(Requirements 14.1, 14.2)',
      (_SnapshotSpec spec) {
        final snapshot = spec.build();
        final bytes = _docx.buildDocx(snapshot);

        // (1) Genuine ZIP: the local-file-header magic bytes "PK\x03\x04".
        expect(bytes.length, greaterThan(4));
        expect(bytes.sublist(0, 4), <int>[0x50, 0x4B, 0x03, 0x04],
            reason: 'buildDocx must emit ZIP/OOXML magic bytes, not raw text');

        // (2) The archive decodes and contains the two parts that make a ZIP a
        // Word document.
        final parts = _unzip(bytes);
        expect(parts.keys, contains('[Content_Types].xml'));
        expect(parts.keys, contains('word/document.xml'));

        // (3) word/document.xml is WordprocessingML, not HTML/PDF text.
        final doc = parts['word/document.xml']!;
        expect(doc, startsWith('<?xml'));
        expect(doc, contains('<w:document'));
        expect(doc, contains('<w:body>'));

        // (4) Never a PDF: no %PDF marker anywhere in any part of the package.
        for (final content in parts.values) {
          expect(content, isNot(contains('%PDF')),
              reason: 'an OOXML package part must never contain a PDF marker');
        }
      },
    );
  });
}
