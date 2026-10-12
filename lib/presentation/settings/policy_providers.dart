/// Riverpod wiring for the app-wide **policy singletons** (task 15.1).
///
/// This file surfaces the three configured policies that the billing and
/// allocation flows read, so every surface (preview, finalize, allocation
/// review) resolves the SAME policy rather than each constructing its own
/// defaults (design.md -> Data Models: AllocationPolicy / TaxPolicy /
/// LoadingPolicy singletons; Settings tab; Requirement 17.11):
///
///   * [allocationPolicyProvider] — the [AllocationPolicy] that governs
///     constrained-CFT allocation: whether the 8–9 ft fallback is enabled
///     (default `false` — excluded, OD-5) and the reaper 60/30/10 length-group
///     shares (design.md CD-4). Always round up / meet-or-exceed is the only
///     allocation direction and is intrinsic to `AllocationService`; the policy
///     only carries the configurable knobs.
///   * [taxModeProvider] — the single-line literal [TaxMode]
///     (`noGst` / `nine` / `eighteen`), defaulting to [TaxMode.noGst]
///     (Requirement 10.5). Never a CGST/SGST split.
///   * [loadingPolicyProvider] — the flat two-tier [LoadingPolicy], defaulting
///     to [LoadingPolicy.standard] (₹100 below 20 CFT, ₹150 at or above 20 CFT
///     inclusive — CD-6).
///
/// Each is a plain `Provider` so a test (or a later first-run / Settings
/// surface — task 15.2, out of scope here) can `overrideWith`/
/// `overrideWithValue` and have the new policy propagate to every reader.
/// Defaults are the owner-confirmed rules, so an app with no configuration
/// still bills and allocates by the confirmed policy.
///
/// Scope (task 15.1): this is the policy **singleton wiring** only. The
/// Settings UI surfaces and first-run setup that let the owner EDIT these are
/// task 15.2. The shared `appDatabaseProvider` is reused (imported from
/// `business_profile_providers.dart`), never redeclared.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/billing_service.dart';

/// The configurable allocation policy singleton (design.md -> Data Models:
/// AllocationPolicy; Requirement 17.11).
///
/// Carries the two knobs the design marks configurable:
///
///   * [allow89ftFallback] — whether 8 ft and 9 ft lengths are eligible in the
///     flexible-reaper heuristic. Defaults to `false`, i.e. 8–9 ft are
///     **excluded** by default (OD-5 / Requirement 8.9). This is the exact
///     `allow89ftFallback` flag `AllocationService.allocateFlexibleReaper`
///     accepts, so a configured policy flows straight into the allocator.
///   * [reaperSharePreferred] / [reaperShareMid] / [reaperShareLow] — the
///     reaper length-group shares for `{6,7}` / `{3,4,5}` / `{2}`, as whole
///     percents defaulting to **60 / 30 / 10** (design.md CD-4). They are kept
///     as integer percents to mirror the drift `AllocationPolicies` singleton
///     columns.
///
/// Allocation is always **round up / meet-or-exceed** — that is the only
/// direction (there is no at-most or closest option) and it lives inside
/// `AllocationService`, so it is not a configurable field here.
@immutable
class AllocationPolicy {
  /// Creates an allocation policy from its configurable knobs.
  const AllocationPolicy({
    this.allow89ftFallback = false,
    this.reaperSharePreferred = 60,
    this.reaperShareMid = 30,
    this.reaperShareLow = 10,
  });

  /// The confirmed default policy: 8–9 ft fallback OFF (lengths excluded,
  /// OD-5), reaper shares 60/30/10 (CD-4).
  static const AllocationPolicy standard = AllocationPolicy();

  /// Whether 8 ft and 9 ft lengths are eligible in flexible-reaper allocation.
  /// Default `false` → excluded (Requirement 8.9, OD-5).
  final bool allow89ftFallback;

  /// Reaper preferred-group (`{6,7}`) share percent. Default 60.
  final int reaperSharePreferred;

  /// Reaper mid-group (`{3,4,5}`) share percent. Default 30.
  final int reaperShareMid;

  /// Reaper low-group (`{2}`) share percent. Default 10.
  final int reaperShareLow;

  /// The preferred-group share as an exact [Rational] fraction (e.g. `60/100`).
  Rational get preferredShare =>
      Rational(BigInt.from(reaperSharePreferred), BigInt.from(100));

  /// The mid-group share as an exact [Rational] fraction (e.g. `30/100`).
  Rational get midShare =>
      Rational(BigInt.from(reaperShareMid), BigInt.from(100));

  /// The low-group share as an exact [Rational] fraction (e.g. `10/100`).
  Rational get lowShare =>
      Rational(BigInt.from(reaperShareLow), BigInt.from(100));

  /// Returns a copy with the given fields replaced.
  AllocationPolicy copyWith({
    bool? allow89ftFallback,
    int? reaperSharePreferred,
    int? reaperShareMid,
    int? reaperShareLow,
  }) {
    return AllocationPolicy(
      allow89ftFallback: allow89ftFallback ?? this.allow89ftFallback,
      reaperSharePreferred: reaperSharePreferred ?? this.reaperSharePreferred,
      reaperShareMid: reaperShareMid ?? this.reaperShareMid,
      reaperShareLow: reaperShareLow ?? this.reaperShareLow,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AllocationPolicy &&
        other.allow89ftFallback == allow89ftFallback &&
        other.reaperSharePreferred == reaperSharePreferred &&
        other.reaperShareMid == reaperShareMid &&
        other.reaperShareLow == reaperShareLow;
  }

  @override
  int get hashCode => Object.hash(
        allow89ftFallback,
        reaperSharePreferred,
        reaperShareMid,
        reaperShareLow,
      );

  @override
  String toString() => 'AllocationPolicy(allow89ftFallback: $allow89ftFallback, '
      'shares: $reaperSharePreferred/$reaperShareMid/$reaperShareLow)';
}

/// The app-wide allocation policy read by the allocation flow (task 15.1).
///
/// Defaults to [AllocationPolicy.standard] (8–9 ft fallback off, reaper
/// 60/30/10). Override in a test or the Settings surface (task 15.2) to change
/// flexible-reaper eligibility and shares for every reader at once.
final allocationPolicyProvider = Provider<AllocationPolicy>((ref) {
  return AllocationPolicy.standard;
});

/// The app-wide tax mode read by the billing flow (task 15.1).
///
/// Defaults to [TaxMode.noGst] (zero tax — Requirement 10.5); the owner selects
/// 9% / 18% in Settings (task 15.2). The computed tax is always a single
/// literal line, never a CGST/SGST split (Requirements 10.1, 10.2).
final taxModeProvider = Provider<TaxMode>((ref) {
  return TaxMode.noGst;
});

/// The app-wide loading policy read by the billing flow (task 15.1).
///
/// Defaults to [LoadingPolicy.standard]: a flat ₹100 below 20 CFT and ₹150 at
/// or above 20 CFT (exactly 20 → ₹150, inclusive — CD-6). Override to retune
/// the tiers/threshold from a later Settings surface (task 15.2).
final loadingPolicyProvider = Provider<LoadingPolicy>((ref) {
  return LoadingPolicy.standard;
});
