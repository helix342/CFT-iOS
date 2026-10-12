/// Editable policy state for the Settings surfaces and first-run setup
/// (task 15.2).
///
/// Task 15.1 wired the three app-wide policy singletons as plain, read-only
/// `Provider`s in `policy_providers.dart` (`allocationPolicyProvider`,
/// `taxModeProvider`, `loadingPolicyProvider`). Those providers deliberately
/// return the owner-confirmed defaults and are the single values every billing
/// and allocation reader resolves.
///
/// This file adds the EDITABLE layer the Settings tab needs WITHOUT changing
/// those definitions. Each controller below is a [Notifier] that holds the
/// owner's current choice; the read-only policy providers are overridden to
/// read the matching controller. The app shell (and the widget tests) install
/// [settingsPolicyOverrides] so editing in Settings flows straight through to
/// every reader while the policy provider *names and types* stay exactly as
/// task 15.1 defined them.
///
/// The controllers default to the SAME owner-confirmed values the plain
/// providers return ([AllocationPolicy.standard], [TaxMode.noGst],
/// [LoadingPolicy.standard]), so an app with no edits still bills and allocates
/// by the confirmed policy.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/presentation/settings/policy_providers.dart';

/// Holds the owner's current [AllocationPolicy] choice for the Settings tab.
///
/// Starts at [AllocationPolicy.standard] (8–9 ft fallback OFF, reaper 60/30/10)
/// and exposes narrow mutators so the Settings UI never constructs a policy by
/// hand. Every mutation emits a new immutable [AllocationPolicy] value.
class AllocationPolicyController extends Notifier<AllocationPolicy> {
  @override
  AllocationPolicy build() => AllocationPolicy.standard;

  /// Enables or disables the 8–9 ft fallback for flexible-reaper allocation
  /// (Requirement 8.9 / OD-5). `false` keeps 8–9 ft excluded (the default).
  void setAllow89ftFallback(bool allow) {
    state = state.copyWith(allow89ftFallback: allow);
  }

  /// Replaces the reaper length-group shares (`{6,7}` / `{3,4,5}` / `{2}` as
  /// whole percents, default 60/30/10 — CD-4).
  void setReaperShares({
    required int preferred,
    required int mid,
    required int low,
  }) {
    state = state.copyWith(
      reaperSharePreferred: preferred,
      reaperShareMid: mid,
      reaperShareLow: low,
    );
  }

  /// Replaces the whole policy value (used by first-run seeding / resets).
  void set(AllocationPolicy policy) => state = policy;
}

/// The editable allocation-policy controller the Settings tab drives.
final allocationPolicyControllerProvider =
    NotifierProvider<AllocationPolicyController, AllocationPolicy>(
  AllocationPolicyController.new,
);

/// Holds the owner's current [TaxMode] choice (No GST / 9% / 18%).
///
/// Starts at [TaxMode.noGst] (zero tax — Requirement 10.5); the tax is always a
/// single literal line, never a CGST/SGST split (Requirements 10.1, 10.2).
class TaxModeController extends Notifier<TaxMode> {
  @override
  TaxMode build() => TaxMode.noGst;

  /// Selects the single-line tax mode.
  void set(TaxMode mode) => state = mode;
}

/// The editable tax-mode controller the Settings tab drives.
final taxModeControllerProvider =
    NotifierProvider<TaxModeController, TaxMode>(TaxModeController.new);

/// Holds the owner's current [LoadingPolicy] (the two ₹100/₹150 tiers and the
/// 20-CFT threshold).
///
/// Starts at [LoadingPolicy.standard] (₹100 below 20 CFT, ₹150 at or above 20
/// CFT inclusive — CD-6). The Settings tab surfaces these tiers for the owner
/// to read/confirm; the value flows into billing through the override below.
class LoadingPolicyController extends Notifier<LoadingPolicy> {
  @override
  LoadingPolicy build() => LoadingPolicy.standard;

  /// Replaces the whole loading policy (used by first-run seeding / resets).
  void set(LoadingPolicy policy) => state = policy;
}

/// The editable loading-policy controller the Settings tab drives.
final loadingPolicyControllerProvider =
    NotifierProvider<LoadingPolicyController, LoadingPolicy>(
  LoadingPolicyController.new,
);

/// The `ProviderScope` overrides that connect the editable controllers to the
/// read-only task-15.1 policy providers.
///
/// Install these at the app root (and in widget tests) so that
/// `allocationPolicyProvider`, `taxModeProvider`, and `loadingPolicyProvider`
/// resolve the owner's edited choice while keeping their original names and
/// types. Without these overrides the policy providers keep returning their
/// standard defaults, so this list is additive and never required for the
/// defaults to hold.
///
/// The element type (`Override`) lives in the core `riverpod` package and is
/// not re-exported by `flutter_riverpod`, so this list's type is left to
/// inference (it resolves to `List<Override>`) rather than named explicitly in
/// source. Callers pass it to `ProviderScope.overrides` / a `ProviderContainer`.
final settingsPolicyOverrides = [
  allocationPolicyProvider
      .overrideWith((ref) => ref.watch(allocationPolicyControllerProvider)),
  taxModeProvider.overrideWith((ref) => ref.watch(taxModeControllerProvider)),
  loadingPolicyProvider
      .overrideWith((ref) => ref.watch(loadingPolicyControllerProvider)),
];
