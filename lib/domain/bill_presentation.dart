/// Pure-Dart bill-presentation rule for the Wood CFT application (task 13.2).
///
/// This file owns the *single* domain rule that decides whether a bill may be
/// presented as a verified, GST-compliant **tax invoice** or must instead be
/// presented as a plain **simple sales bill**. The invoice preview and the
/// DOCX/share exports (tasks 11/12) consume this rule for their headers; they
/// do not re-derive the decision themselves, so a preview and its export can
/// never disagree about what kind of document is being produced.
///
/// Rule (Requirement 18.6, design.md -> Correctness Property 31 / OD-9):
///   A bill is a verified compliant **tax invoice** only when the configured
///   statutory identity fields are COMPLETE. "Complete" here means, at
///   minimum, all of:
///     * a non-empty GSTIN (the registration identifier), and
///     * a non-empty business name, and
///     * a non-empty business address.
///   If ANY of those is missing/blank the bill is a [BillKind.simpleSalesBill]
///   and MUST NOT be labelled a verified compliant tax invoice.
///
/// Honesty: statutory details are never fabricated. The default empty profile
/// ([BusinessProfile.empty]) therefore classifies as a simple sales bill
/// (Requirement 18.2, 18.5).
///
/// Architecture rule (design.md): the domain layer stays pure Dart and MUST
/// NOT import `package:flutter/*` or `dart:io`.
library;

import 'package:meta/meta.dart';
import 'package:wood_cft/domain/business_settings.dart';

/// The kind of document a bill is presented as.
///
/// There are exactly two kinds. A bill is only ever a [taxInvoice] when the
/// business profile carries complete statutory fields; otherwise it is a
/// [simpleSalesBill] (Requirement 18.6, Correctness Property 31).
enum BillKind {
  /// A plain sales bill. Used whenever the statutory tax-invoice fields are
  /// incomplete. This is the honest default and never claims GST compliance.
  simpleSalesBill,

  /// A verified, GST-compliant tax invoice. Only produced when the business
  /// profile supplies all required statutory fields (name, address, GSTIN).
  taxInvoice,
}

/// Human-readable header labels for each [BillKind].
///
/// The preview/export headers (tasks 11/12) render exactly these strings, so a
/// simple sales bill is never shown with tax-invoice wording and vice versa.
extension BillKindLabel on BillKind {
  /// The header label the preview/export should display for this kind.
  String get label {
    switch (this) {
      case BillKind.taxInvoice:
        return 'Tax Invoice';
      case BillKind.simpleSalesBill:
        return 'Sales Bill';
    }
  }

  /// Whether this kind may be presented as a verified compliant tax invoice.
  ///
  /// Only [BillKind.taxInvoice] is a verified compliant tax invoice; a
  /// [BillKind.simpleSalesBill] is never presented as one (Requirement 18.6).
  bool get isVerifiedTaxInvoice => this == BillKind.taxInvoice;
}

/// The domain rule classifying how a bill may be presented.
///
/// This is a pure, side-effect-free classifier over a [BusinessProfile]. It is
/// the one place that answers "tax invoice or simple sales bill?" so every
/// downstream surface stays consistent (Correctness Property 31).
@immutable
abstract final class BillPresentation {
  /// Returns `true` when [value] is non-null and not blank (ignoring
  /// surrounding whitespace). Blank/whitespace-only values count as missing so
  /// a profile cannot "complete" a statutory field with empty spaces.
  static bool _isPresent(String? value) =>
      value != null && value.trim().isNotEmpty;

  /// Whether [profile] supplies every statutory field required to present a
  /// verified compliant tax invoice.
  ///
  /// Requires a non-empty GSTIN, business name, and business address. Returns
  /// `false` for the empty profile and for any partially-configured profile
  /// (Requirement 18.6, Correctness Property 31).
  static bool hasCompleteTaxInvoiceFields(BusinessProfile profile) {
    return _isPresent(profile.gstin) &&
        _isPresent(profile.name) &&
        _isPresent(profile.address);
  }

  /// Classifies the kind of bill [profile] may be presented as.
  ///
  /// Returns [BillKind.taxInvoice] only when
  /// [hasCompleteTaxInvoiceFields] holds; otherwise returns
  /// [BillKind.simpleSalesBill]. The default empty profile always classifies
  /// as a simple sales bill (Requirement 18.2, 18.5, 18.6).
  static BillKind classify(BusinessProfile profile) {
    return hasCompleteTaxInvoiceFields(profile)
        ? BillKind.taxInvoice
        : BillKind.simpleSalesBill;
  }

  /// Convenience: the header label the preview/export should use for [profile].
  ///
  /// Equivalent to `classify(profile).label`.
  static String labelFor(BusinessProfile profile) => classify(profile).label;
}
