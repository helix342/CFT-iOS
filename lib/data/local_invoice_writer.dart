/// Persists a finalized sale into the local `Invoices` / `InvoiceLines` tables
/// (app-ux-revamp Requirement 4.5, 6.5).
///
/// The hosted finalize transaction (`FinalizeService.finalizeSale`) remains the
/// authoritative sale; this writer additionally mirrors the resulting
/// [FinalizedInvoice] into the local drift cache so the dashboard and Bills tab
/// have real sales data before the Supabase backend exists (Requirement 6.5,
/// OD-8). It REUSES the existing `Invoices` + `InvoiceLines` tables — no new
/// sales table is introduced.
///
/// Writing is idempotent under the invoice idempotency key: the `Invoices`
/// table has a unique `idempotencyKey`, and this writer first checks for an
/// existing row, so persisting the same finalize twice yields exactly one local
/// invoice (inherits finalize Property 19; design Property 34).
///
/// Money is stored as integer paise and CFT as an exact numerator/denominator
/// pair, mapped straight from the [FinalizedInvoice]'s exact value objects, so
/// no floating-point drift is introduced.
library;

import 'package:drift/drift.dart';

import 'package:wood_cft/application/finalize_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/tables.dart';

/// Maps a [FinalizedInvoice] to local `Invoices` / `InvoiceLines` rows.
class LocalInvoiceWriter {
  /// Creates the writer over [db].
  const LocalInvoiceWriter(this.db);

  /// The local cache database the invoice is written to.
  final AppDatabase db;

  /// Computes the next PERSISTENT local invoice number from the existing
  /// `Invoices` rows: one greater than the highest numeric suffix currently
  /// stored (so the sequence is monotonically increasing and never collides),
  /// or `1` when no invoice has been written yet.
  ///
  /// The number is derived from the stored `invoiceNumber` text by parsing the
  /// trailing integer of each row's `INV-<n>` display value and taking
  /// `max(..) + 1`. This is what lets repeated finalizes get `INV-1`, `INV-2`,
  /// `INV-3`… with no `UNIQUE(invoiceNumber)` violation, independent of the
  /// in-memory [InvoiceNumberAllocator] seed (which always restarts at 1).
  ///
  /// Callers that need the number stable across the whole finalize should seed
  /// their [InvoiceNumberAllocator] with this value AND store the matching
  /// `INV-<n>` text via [write]'s `invoiceNumberText`, so the allocated number
  /// and the stored number agree.
  Future<int> nextInvoiceNumber() => _nextNumberInTxn();

  /// The shared max-suffix-plus-one computation, usable both standalone and
  /// from inside the [write] transaction.
  Future<int> _nextNumberInTxn() async {
    final rows = await db.select(db.invoices).get();
    var maxNumber = 0;
    for (final row in rows) {
      final n = _numericSuffix(row.invoiceNumber);
      if (n != null && n > maxNumber) {
        maxNumber = n;
      }
    }
    return maxNumber + 1;
  }

  /// Parses the trailing integer of an `INV-<n>` display number, or `null` when
  /// the text carries no trailing integer.
  static int? _numericSuffix(String invoiceNumber) {
    final match = RegExp(r'(\d+)$').firstMatch(invoiceNumber);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// Persists [invoice] into the local tables and returns the local invoice id.
  ///
  /// Idempotent under [FinalizedInvoice.idempotencyKey]: if an invoice with the
  /// same key already exists, no second row is written and the existing id is
  /// returned (design Property 34). [invoiceNumberText] is the display number
  /// stored on the row (defaults to `INV-<number>`); [customerName] /
  /// [customerPhone] snapshot the buyer; the policy/business snapshots default
  /// to empty JSON objects when the caller has none to record.
  Future<int> write(
    FinalizedInvoice invoice, {
    String? invoiceNumberText,
    String? customerName,
    String? customerPhone,
    DateTime? finalizedAt,
    String taxPolicySnapshot = '{}',
    String loadingPolicySnapshot = '{}',
    String businessProfileSnapshot = '{}',
  }) {
    return db.transaction(() async {
      // Idempotent guard: the same finalize key yields exactly one local row.
      final existing = await (db.select(db.invoices)
            ..where((i) => i.idempotencyKey.equals(invoice.idempotencyKey)))
          .getSingleOrNull();
      if (existing != null) return existing.id;

      final totals = invoice.totals;
      final totalCft = totals.totalCft.value;

      // Resolve the stored, UNIQUE display number INSIDE the transaction. The
      // caller normally supplies the persistent `INV-<n>` text (and seeds its
      // allocator with the same n), but as a defensive guard an unsupplied
      // number is computed here from the current rows so two different orders
      // can never both store `INV-1` and trip the UNIQUE(invoiceNumber)
      // constraint.
      final storedNumberText =
          invoiceNumberText ?? 'INV-${await _nextNumberInTxn()}';

      final invoiceId = await db.into(db.invoices).insert(
            InvoicesCompanion.insert(
              invoiceNumber: storedNumberText,
              status: InvoiceStatus.finalized,
              customerName: Value(customerName),
              customerPhone: Value(customerPhone),
              goodsSubtotalPaise: totals.goodsSubtotal.paise.toInt(),
              taxPaise: totals.tax.paise.toInt(),
              loadingPaise: totals.loading.paise.toInt(),
              payablePaise: totals.payable.paise.toInt(),
              totalCftNum: totalCft.numerator.toInt(),
              totalCftDen: totalCft.denominator.toInt(),
              taxPolicySnapshot: taxPolicySnapshot,
              loadingPolicySnapshot: loadingPolicySnapshot,
              businessProfileSnapshot: businessProfileSnapshot,
              finalizedAt: (finalizedAt ?? DateTime.now()).toUtc(),
              idempotencyKey: invoice.idempotencyKey,
            ),
          );

      for (final line in invoice.lines) {
        final cft = line.cft.value;
        await db.into(db.invoiceLines).insert(
              InvoiceLinesCompanion.insert(
                invoiceId: invoiceId,
                varietyName: line.varietyName,
                crossSectionLabel: line.label,
                lengthFt: line.lengthFt,
                pieces: line.pieces,
                exactCftNum: cft.numerator.toInt(),
                exactCftDen: cft.denominator.toInt(),
                rateNum: line.rate.numerator.toInt(),
                rateDen: line.rate.denominator.toInt(),
                lineAmountPaise: line.amount.paise.toInt(),
              ),
            );
      }

      return invoiceId;
    });
  }
}
