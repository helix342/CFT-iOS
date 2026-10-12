/// WhatsApp-ready plain-text invoice generation from a finalized invoice
/// snapshot (task 12.2).
///
/// `WhatsAppExportService` turns the same immutable [InvoiceSnapshot] the
/// on-screen preview and the DOCX export consume into a **human-readable,
/// WhatsApp-formatted** message (Requirement 15.1). Because every surface reads
/// the one snapshot -- and this service formats every monetary and CFT value
/// through the exact same `Money.format` / `Cft.toFixed` helpers the DOCX
/// export uses -- the WhatsApp text values match the preview and the Word
/// document exactly (Requirements 15.1, 15.3; Correctness Property 27).
///
/// Formatting rules (Requirement 15.2; design.md -> Export Strategy -> WhatsApp
/// text):
///   * simple headings and line breaks,
///   * WhatsApp emphasis using `*bold*` for the business name and the payable
///     total, and
///   * **no Markdown tables** -- items are rendered as indented text lines, so
///     the output never contains pipe/dash table syntax.
///
/// The document title honors the simple-sales-bill vs tax-invoice distinction
/// via the shared [BillKind] rule carried on the snapshot
/// (`bill_presentation.dart`), so a preview and its WhatsApp text can never
/// disagree about the document kind (Requirement 18.6).
///
/// Scope: this is a **pure value->String** function and performs no I/O. The
/// share-sheet / clipboard wiring (Share invoice file, Share bill text, Copy
/// bill text, and the generic fallback) and the never-re-deduct-on-share rule
/// are task 12.3's concern (Requirements 15.4-15.6); nothing here touches the
/// share sheet, the clipboard, or the database, so it runs headless under
/// `flutter test` on Windows.
///
/// Architecture note: this service lives in the application layer and depends
/// only on the pure domain types and the snapshot model exposed by
/// `docx_export_service.dart` (it imports [InvoiceSnapshot] rather than
/// redefining it). It does not import `package:flutter/*` and performs no I/O.
library;

import 'package:meta/meta.dart';

import 'package:wood_cft/application/docx_export_service.dart';
import 'package:wood_cft/domain/bill_presentation.dart';

/// Pure value->String generator for the WhatsApp text export (task 12.2).
///
/// Stateless; a single `const` instance can be shared. [buildMessage] renders
/// an [InvoiceSnapshot] into the WhatsApp-ready message string.
@immutable
class WhatsAppExportService {
  /// Creates the WhatsApp export service.
  const WhatsAppExportService();

  /// Builds the WhatsApp-ready plain-text message for [snapshot].
  ///
  /// Compact ledger layout (matching the owner's examples): a date + shop/
  /// customer header, one aligned `description .... amount` line per item, a
  /// divider, the loading charge, and a bold grand total. No Markdown tables.
  String buildMessage(InvoiceSnapshot snapshot) {
    final b = StringBuffer();
    final business = snapshot.business;
    final shopName =
        business.name.trim().isEmpty ? snapshot.kind.label : business.name.trim();

    // Header: date + shop, then the customer on its own line.
    b.writeln('${snapshot.dateLabel}  $shopName');
    final customer = snapshot.customerName.trim();
    if (customer.isNotEmpty) {
      final phone = snapshot.customerPhone.trim();
      b.writeln(phone.isEmpty ? customer : '$customer  $phone');
    }
    b.writeln('');

    // Item lines: "<desc> ............ <amount>" right-aligned into a width.
    for (final line in snapshot.lines) {
      final desc = '${line.variety} ${line.crossSection} '
          '${line.lengthFt}ft  ${line.units}';
      b.writeln(_ledgerLine(desc, line.amount.format()));
    }

    b.writeln(_sep);
    b.writeln(_ledgerLine('Goods', snapshot.totals.goodsSubtotal.format()));
    if (snapshot.totals.tax.paise > BigInt.zero) {
      b.writeln(
        _ledgerLine('Tax (${snapshot.totals.taxLabel})',
            snapshot.totals.tax.format()),
      );
    }
    if (snapshot.totals.loading.paise > BigInt.zero) {
      b.writeln(_ledgerLine('Loading', snapshot.totals.loading.format()));
    }
    b.writeln(_sep);
    // Grand total emphasised with WhatsApp *bold*.
    b.write('*${_ledgerLine('Total', snapshot.totals.payable.format())}*');

    return b.toString();
  }

  /// The total character width each ledger line is padded to, so the amounts
  /// line up on the right in a monospace WhatsApp view.
  static const int _lineWidth = 32;

  /// A separator row of asterisks (matching the owner's examples).
  static const String _sep = '***';

  /// Formats one `label ........... amount` row, left label + right-aligned
  /// amount padded with spaces to [_lineWidth]. Long labels simply get a single
  /// space before the amount so nothing is truncated.
  String _ledgerLine(String label, String amount) {
    final pad = _lineWidth - label.length - amount.length;
    final gap = pad > 1 ? ' ' * pad : ' ';
    return '$label$gap$amount';
  }
}
