/// Share/export wiring for a finalized order invoice (app-ux-revamp
/// Requirement 4.6; FIX 3).
///
/// Bridges a [FinalizedInvoice] (the immutable result of
/// `FinalizeService.finalizeSale`) and the active [BusinessProfile] into the
/// shared [InvoiceSnapshot] the export generators consume, and exposes an
/// [InvoiceShareService] bound to the production [PlatformShareBackend] so the
/// sold-order UI can offer "Share Word (.docx)", "Share bill text (WhatsApp)",
/// and "Copy bill text".
///
/// Sharing is a pure read of the already-finalized invoice: building the
/// snapshot runs no allocation / finalize / billing-mutation and the backend
/// only forwards an already-built payload to the OS, so sharing never
/// re-deducts stock (Requirement 15.6).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/application/docx_export_service.dart'
    show InvoiceLineSnapshot, InvoiceSnapshot;
// Hide the finalize-service InvoiceLineSnapshot so the docx-export one above is
// unambiguous; FinalizedInvoice is the only type needed from finalize_service.
import 'package:wood_cft/application/finalize_service.dart'
    show FinalizedInvoice;
import 'package:wood_cft/application/invoice_share_backend_platform.dart';
import 'package:wood_cft/application/invoice_share_service.dart';
import 'package:wood_cft/domain/business_settings.dart';

/// The production invoice-share coordinator, bound to the device-backed
/// [PlatformShareBackend] (share sheet + clipboard).
final invoiceShareServiceProvider = Provider<InvoiceShareService>(
  (ref) => const InvoiceShareService(backend: PlatformShareBackend()),
);

/// Builds the shared [InvoiceSnapshot] from a finalized [invoice] and the
/// active [business] profile, re-pricing each sold line through the shared
/// [BillingService] so the exported CFT / rate / amount match the preview
/// exactly.
///
/// [dateLabel] is a pre-formatted invoice date (e.g. `21-05-2024`); it defaults
/// to the current date in `dd-MM-yyyy` when omitted.
InvoiceSnapshot buildInvoiceSnapshot({
  required FinalizedInvoice invoice,
  required BusinessProfile business,
  String? customerName,
  String? customerPhone,
  String? dateLabel,
  BillingService billing = const BillingService(),
}) {
  final lines = <InvoiceLineSnapshot>[
    for (final line in invoice.lines)
      InvoiceLineSnapshot(
        variety: line.varietyName,
        crossSection: line.label,
        lengthFt: line.lengthFt,
        units: '${line.pieces} pcs',
        goods: billing.priceLine(
          GoodsLineInput(
            stockItemId: line.stockItemId,
            varietyId: line.varietyId,
            crossSectionId: 0,
            lengthFt: line.lengthFt,
            allocatedCft: line.cft,
            rate: line.rate,
          ),
        ),
      ),
  ];

  final prefix = business.invoicePrefix.trim();
  final numberText =
      prefix.isEmpty ? 'INV-${invoice.number}' : '$prefix${invoice.number}';

  return InvoiceSnapshot(
    business: business,
    invoiceNumber: numberText,
    dateLabel: dateLabel ?? _todayLabel(),
    customerName: (customerName ?? '').trim().isEmpty
        ? 'Walk-in'
        : customerName!.trim(),
    customerPhone: (customerPhone ?? '').trim(),
    lines: lines,
    totals: invoice.totals,
  );
}

/// A `dd-MM-yyyy` label for today's date (local time).
String _todayLabel() {
  final now = DateTime.now();
  final dd = now.day.toString().padLeft(2, '0');
  final mm = now.month.toString().padLeft(2, '0');
  return '$dd-$mm-${now.year}';
}
