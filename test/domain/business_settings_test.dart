/// Unit tests for the pure-Dart [BusinessProfile] domain model (task 13.1).
///
/// Pins the Requirement 18 honesty rules at the model level:
///   * [BusinessProfile.empty] has a blank name — never "Zenith Systems"
///     (Requirement 18.2);
///   * [BusinessProfile.empty] has an absent (null) GSTIN — no fabricated
///     registration (Requirement 18.5);
///   * `copyWith` edits fields and can clear the nullable logo/GSTIN.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wood_cft/domain/business_settings.dart';

void main() {
  group('BusinessProfile.empty', () {
    test('has a blank name (never assumes "Zenith Systems") — Req 18.2', () {
      expect(BusinessProfile.empty.name, isEmpty);
      expect(BusinessProfile.empty.name, isNot(contains('Zenith')));
    });

    test('does not fabricate registration details — Req 18.5', () {
      expect(BusinessProfile.empty.gstin, isNull);
      expect(BusinessProfile.empty.logo, isNull);
    });

    test('has empty address, phone, and invoice prefix', () {
      expect(BusinessProfile.empty.address, isEmpty);
      expect(BusinessProfile.empty.phone, isEmpty);
      expect(BusinessProfile.empty.invoicePrefix, isEmpty);
    });
  });

  group('copyWith', () {
    test('replaces individual fields and leaves the rest unchanged', () {
      const base = BusinessProfile(
        name: 'A',
        address: 'Addr',
        phone: '123',
        gstin: 'GST1',
        invoicePrefix: 'INV-',
      );

      final edited = base.copyWith(name: 'B');

      expect(edited.name, 'B');
      expect(edited.address, 'Addr');
      expect(edited.phone, '123');
      expect(edited.gstin, 'GST1');
      expect(edited.invoicePrefix, 'INV-');
    });

    test('clears the nullable gstin via clearGstin', () {
      const base = BusinessProfile(gstin: 'GST1');
      expect(base.copyWith(clearGstin: true).gstin, isNull);
    });

    test('clears the nullable logo via clearLogo', () {
      final base = BusinessProfile(logo: Uint8List.fromList([1, 2, 3]));
      expect(base.copyWith(clearLogo: true).logo, isNull);
    });
  });

  group('equality', () {
    test('two profiles with equal fields (incl. logo bytes) are equal', () {
      final a = BusinessProfile(
        name: 'A',
        logo: Uint8List.fromList([1, 2, 3]),
      );
      final b = BusinessProfile(
        name: 'A',
        logo: Uint8List.fromList([1, 2, 3]),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differing logo bytes make profiles unequal', () {
      final a = BusinessProfile(logo: Uint8List.fromList([1, 2, 3]));
      final b = BusinessProfile(logo: Uint8List.fromList([9, 9, 9]));
      expect(a, isNot(equals(b)));
    });
  });
}
