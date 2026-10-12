/// Pure-Dart business-profile domain model for the Wood CFT application
/// (task 13.1).
///
/// [BusinessProfile] is the immutable shop-identity value object from
/// design.md -> Data Models (BusinessSettings) and Requirement 18. It carries
/// the statutory/identity fields an invoice needs: business `name`, `address`,
/// `phone`, an optional `logo`, an optional `gstin`, and the `invoicePrefix`
/// that feeds invoice numbering at finalize time (task 11).
///
/// Honesty rules baked into this model (Requirement 18):
///   * The business name is NEVER assumed to be "Zenith Systems"
///     (Requirement 18.2) — [BusinessProfile.empty] has a blank name.
///   * Registration details are NEVER fabricated (Requirement 18.5) —
///     `gstin` defaults to `null` (absent), not an invented value.
///
/// Architecture rule (design.md): the domain layer stays pure Dart and MUST
/// NOT import `package:flutter/*` or `dart:io`. Persistence of this value
/// (the drift singleton row) lives in `lib/data/business_settings_repository`,
/// not here.
library;

import 'dart:typed_data';

import 'package:meta/meta.dart';

/// The immutable business profile (shop identity) used on bills and invoices.
///
/// All fields default to empty/absent so a fresh install represents *no*
/// configured identity rather than a fabricated one (Requirement 18.2, 18.5).
@immutable
class BusinessProfile {
  /// Creates a business profile.
  ///
  /// [name], [address], [phone], and [invoicePrefix] are plain strings that
  /// default to empty. [logo] and [gstin] are optional and default to absent
  /// (`null`); an absent [gstin] means no registration detail has been
  /// configured and MUST NOT be fabricated (Requirement 18.5).
  const BusinessProfile({
    this.name = '',
    this.address = '',
    this.phone = '',
    this.logo,
    this.gstin,
    this.invoicePrefix = '',
  });

  /// The business name (Requirement 18.1). Blank until the owner configures it;
  /// never defaulted to any assumed name (Requirement 18.2).
  final String name;

  /// The business address (Requirement 18.1).
  final String address;

  /// The business phone (Requirement 18.1).
  final String phone;

  /// Optional logo bytes (Requirement 18.1). `null` when none is configured.
  final Uint8List? logo;

  /// Optional GSTIN (Requirement 18.1). `null` means no registration detail is
  /// configured; it is never fabricated (Requirement 18.5).
  final String? gstin;

  /// The invoice-number prefix (Requirement 18.1). Feeds invoice numbering at
  /// finalize time (task 11); empty until configured.
  final String invoicePrefix;

  /// The empty profile for a fresh install: no name (Requirement 18.2), no
  /// GSTIN or other fabricated registration (Requirement 18.5), no logo.
  static const BusinessProfile empty = BusinessProfile();

  /// Returns a copy of this profile with the given fields replaced.
  ///
  /// [logo] and [gstin] are nullable fields, so a sentinel is used to tell
  /// "leave unchanged" apart from "clear to null": pass [clearLogo] /
  /// [clearGstin] to set them back to `null`.
  BusinessProfile copyWith({
    String? name,
    String? address,
    String? phone,
    Uint8List? logo,
    bool clearLogo = false,
    String? gstin,
    bool clearGstin = false,
    String? invoicePrefix,
  }) {
    return BusinessProfile(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      logo: clearLogo ? null : (logo ?? this.logo),
      gstin: clearGstin ? null : (gstin ?? this.gstin),
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BusinessProfile &&
        other.name == name &&
        other.address == address &&
        other.phone == phone &&
        _bytesEqual(other.logo, logo) &&
        other.gstin == gstin &&
        other.invoicePrefix == invoicePrefix;
  }

  @override
  int get hashCode => Object.hash(
    name,
    address,
    phone,
    logo == null ? null : Object.hashAll(logo!),
    gstin,
    invoicePrefix,
  );

  @override
  String toString() =>
      'BusinessProfile(name: $name, address: $address, phone: $phone, '
      'logo: ${logo == null ? 'none' : '${logo!.length} bytes'}, '
      'gstin: $gstin, invoicePrefix: $invoicePrefix)';

  static bool _bytesEqual(Uint8List? a, Uint8List? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
