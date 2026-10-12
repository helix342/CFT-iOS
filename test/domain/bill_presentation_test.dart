/// Unit tests for the pure-Dart bill-presentation rule (task 13.2).
///
/// Pins Requirement 18.6 / Correctness Property 31 at the domain level:
///   * an empty or partially-configured profile (no GSTIN, or missing name /
///     address) classifies as a [BillKind.simpleSalesBill] and is NEVER a
///     verified compliant tax invoice;
///   * a fully-populated profile (GSTIN + name + address) classifies as a
///     [BillKind.taxInvoice];
///   * the header label text reflects the classified kind.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wood_cft/domain/bill_presentation.dart';
import 'package:wood_cft/domain/business_settings.dart';

/// A profile with every statutory tax-invoice field present.
const BusinessProfile _complete = BusinessProfile(
  name: 'Acme Timber',
  address: '12 Mill Road, Chennai',
  phone: '9000000000',
  gstin: '33ABCDE1234F1Z5',
  invoicePrefix: 'INV-',
);

void main() {
  group('simple sales bill (incomplete statutory fields) — Req 18.6', () {
    test('empty profile defaults to a simple sales bill', () {
      expect(
        BillPresentation.classify(BusinessProfile.empty),
        BillKind.simpleSalesBill,
      );
      expect(
        BillPresentation.hasCompleteTaxInvoiceFields(BusinessProfile.empty),
        isFalse,
      );
    });

    test('missing GSTIN → simple sales bill, never a tax invoice', () {
      final noGstin = _complete.copyWith(clearGstin: true);

      expect(BillPresentation.classify(noGstin), BillKind.simpleSalesBill);
      expect(
        BillPresentation.classify(noGstin).isVerifiedTaxInvoice,
        isFalse,
      );
    });

    test('blank/whitespace GSTIN counts as missing → simple sales bill', () {
      final blankGstin = _complete.copyWith(gstin: '   ');

      expect(BillPresentation.classify(blankGstin), BillKind.simpleSalesBill);
    });

    test('missing address → simple sales bill', () {
      final noAddress = _complete.copyWith(address: '');

      expect(BillPresentation.classify(noAddress), BillKind.simpleSalesBill);
      expect(
        BillPresentation.hasCompleteTaxInvoiceFields(noAddress),
        isFalse,
      );
    });

    test('missing name → simple sales bill', () {
      final noName = _complete.copyWith(name: '');

      expect(BillPresentation.classify(noName), BillKind.simpleSalesBill);
    });

    test('a simple sales bill is never a verified tax invoice', () {
      expect(
        BillKind.simpleSalesBill.isVerifiedTaxInvoice,
        isFalse,
      );
    });
  });

  group('tax invoice (complete statutory fields) — Req 18.6', () {
    test('fully-populated profile classifies as a tax invoice', () {
      expect(BillPresentation.classify(_complete), BillKind.taxInvoice);
      expect(
        BillPresentation.hasCompleteTaxInvoiceFields(_complete),
        isTrue,
      );
    });

    test('a tax invoice is a verified compliant tax invoice', () {
      expect(BillKind.taxInvoice.isVerifiedTaxInvoice, isTrue);
    });

    test('surrounding whitespace is trimmed when checking presence', () {
      const padded = BusinessProfile(
        name: '  Acme Timber  ',
        address: '  12 Mill Road  ',
        gstin: '  33ABCDE1234F1Z5  ',
      );

      expect(BillPresentation.classify(padded), BillKind.taxInvoice);
    });
  });

  group('header labels reflect the kind', () {
    test('tax invoice label', () {
      expect(BillKind.taxInvoice.label, 'Tax Invoice');
      expect(BillPresentation.labelFor(_complete), 'Tax Invoice');
    });

    test('simple sales bill label', () {
      expect(BillKind.simpleSalesBill.label, 'Sales Bill');
      expect(BillPresentation.labelFor(BusinessProfile.empty), 'Sales Bill');
    });

    test('the simple-bill label never contains tax-invoice wording', () {
      expect(
        BillKind.simpleSalesBill.label.toLowerCase(),
        isNot(contains('tax invoice')),
      );
    });
  });
}
