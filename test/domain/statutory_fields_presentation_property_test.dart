// Property-based test for the statutory-field bill-presentation rule
// (task 17.1 — fills the previously-missing Property 31).
//
//   * Property 31 - Incomplete statutory fields prevent a verified tax-invoice
//     presentation (design.md -> Correctness Properties; Requirement 18.6):
//     *For all* business settings missing any required tax-invoice statutory
//     field, the produced bill is presented as a simple sales bill and NEVER as
//     a verified compliant tax invoice.
//
// There is already example-level coverage of the rule in
// `bill_presentation_test.dart`; this is the single *property* test the design
// mandates for Property 31 — it drives `BillPresentation` across many randomly
// generated profiles (>= 100 iterations) rather than a handful of fixed cases.
//
// PBT framework: `package:glados`. `ExploreConfig(numRuns: ...)` fixes the
// iteration count (>= 100) and seeds a deterministic `Random`, so a failure
// reproduces exactly.
//
// Pure-Dart domain test: imports only the domain layer and `package:glados`
// (which re-exports `package:test`). No Flutter widgets, no dart:io.

import 'package:glados/glados.dart';

import 'package:wood_cft/domain/bill_presentation.dart';
import 'package:wood_cft/domain/business_settings.dart';

/// Deterministic exploration config giving the property >= 100 iterations from
/// a fixed seed.
final ExploreConfig _explore =
    ExploreConfig(numRuns: 200, random: Random(20240731));

/// A field value that is randomly either present (a non-blank token) or
/// "missing" — modelled as `null`, the empty string, or whitespace-only, since
/// `BillPresentation` treats all three as absent.
final Generator<String?> _maybeField = any.choose<String?>([
  null,
  '',
  '   ',
  '\t',
  'Acme Timber',
  '12 Mill Road, Chennai',
  '33ABCDE1234F1Z5',
  '  padded value  ',
]);

/// A randomly generated business profile with independently present-or-missing
/// name / address / GSTIN (phone and prefix are irrelevant to the rule).
class _Profile {
  const _Profile(this.name, this.address, this.gstin);

  final String? name;
  final String? address;
  final String? gstin;

  BusinessProfile toProfile() => BusinessProfile(
        name: name ?? '',
        address: address ?? '',
        gstin: gstin,
      );

  /// Mirrors `BillPresentation`'s notion of "present": non-null and not blank
  /// after trimming. Rebuilt here independently so the property checks the rule
  /// against its own definition rather than the code under test.
  static bool _present(String? v) => v != null && v.trim().isNotEmpty;

  /// Whether EVERY statutory field is present — the only case that may be a
  /// verified tax invoice.
  bool get allStatutoryPresent =>
      _present(name) && _present(address) && _present(gstin);

  @override
  String toString() =>
      '_Profile(name: $name, address: $address, gstin: $gstin)';
}

/// Generator combining the three independently-present-or-missing fields.
final Generator<_Profile> _profile = any.combine3(
  _maybeField,
  _maybeField,
  _maybeField,
  _Profile.new,
);

void main() {
  Glados<_Profile>(_profile, _explore).test(
    'Feature: wood-cft-app, Property 31: Incomplete statutory fields prevent a '
    'verified tax-invoice presentation - for all business settings missing any '
    'required statutory field (name, address, GSTIN), the bill is presented as '
    'a simple sales bill and never as a verified compliant tax invoice '
    '(Requirement 18.6)',
    (_Profile p) {
      final profile = p.toProfile();
      final kind = BillPresentation.classify(profile);

      if (p.allStatutoryPresent) {
        // Complete statutory fields: the only case that may be a tax invoice.
        expect(kind, BillKind.taxInvoice);
        expect(kind.isVerifiedTaxInvoice, isTrue);
        expect(BillPresentation.labelFor(profile), 'Tax Invoice');
      } else {
        // ANY missing/blank statutory field -> simple sales bill, and NEVER a
        // verified compliant tax invoice. This is the universal direction the
        // property guards (Requirement 18.6).
        expect(kind, BillKind.simpleSalesBill);
        expect(kind.isVerifiedTaxInvoice, isFalse);
        expect(BillPresentation.labelFor(profile), 'Sales Bill');
        expect(
          BillPresentation.labelFor(profile).toLowerCase(),
          isNot(contains('tax invoice')),
        );
      }

      // The classifier is total and consistent with its own completeness
      // predicate for every generated profile.
      expect(
        kind == BillKind.taxInvoice,
        BillPresentation.hasCompleteTaxInvoiceFields(profile),
      );
    },
  );
}
