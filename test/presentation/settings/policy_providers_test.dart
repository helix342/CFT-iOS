// Riverpod wiring tests for the app-wide policy singletons (task 15.1).
//
// Confirms the three policy providers default to the OWNER-CONFIRMED rules and
// that an override propagates to every reader through a single ProviderContainer:
//   * allocation — always round up / meet-or-exceed, 8–9 ft fallback OFF,
//     reaper shares 60/30/10 (design.md CD-4, OD-5; Requirement 17.11);
//   * loading — flat ₹100 below 20 CFT, ₹150 at/above 20 CFT inclusive (CD-6);
//   * tax mode — defaults to No GST (Requirement 10.5).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/domain/cft.dart';
import 'package:wood_cft/domain/money.dart';
import 'package:wood_cft/presentation/settings/policy_providers.dart';

void main() {
  group('policy singleton defaults match the owner-confirmed rules', () {
    test('allocation policy: round-up is intrinsic, 8–9 ft off, shares 60/30/10',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final policy = container.read(allocationPolicyProvider);

      // 8–9 ft excluded by default (OD-5 / Requirement 8.9).
      expect(policy.allow89ftFallback, isFalse);
      // Reaper 60/30/10 length-group shares (CD-4).
      expect(policy.reaperSharePreferred, 60);
      expect(policy.reaperShareMid, 30);
      expect(policy.reaperShareLow, 10);
      // Exposed as exact rational fractions summing to 1 (meet-or-exceed never
      // loses or invents CFT across the groups).
      expect(policy.preferredShare, Rational(BigInt.from(60), BigInt.from(100)));
      expect(policy.midShare, Rational(BigInt.from(30), BigInt.from(100)));
      expect(policy.lowShare, Rational(BigInt.from(10), BigInt.from(100)));
      expect(
        policy.preferredShare + policy.midShare + policy.lowShare,
        Rational.one,
      );
    });

    test('loading policy: ₹100 below 20 CFT, ₹150 at/above 20 CFT inclusive', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final loading = container.read(loadingPolicyProvider);

      expect(loading.low, Money.fromRupees(100));
      expect(loading.high, Money.fromRupees(150));
      expect(loading.thresholdCft, Cft.fromInt(20));
      expect(loading.thresholdInclusive, isTrue);

      // The step function on EXACT CFT: below 20 → ₹100; exactly 20 and above
      // → ₹150; an empty order carries no loading.
      expect(loading.chargeFor(Cft.zero), Money.zero);
      expect(
        loading.chargeFor(Cft(Rational.fromInt(19))),
        Money.fromRupees(100),
      );
      expect(
        loading.chargeFor(Cft(Rational(BigInt.from(1999), BigInt.from(100)))),
        Money.fromRupees(100),
      );
      expect(loading.chargeFor(Cft.fromInt(20)), Money.fromRupees(150));
      expect(loading.chargeFor(Cft.fromInt(25)), Money.fromRupees(150));
    });

    test('tax mode defaults to No GST (zero tax, single line)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mode = container.read(taxModeProvider);
      expect(mode, TaxMode.noGst);
      expect(mode.rate, Rational.zero);
    });
  });

  group('overrides propagate to every reader', () {
    test('allocation policy override flips the 8–9 ft fallback and shares', () {
      final container = ProviderContainer(
        overrides: [
          allocationPolicyProvider.overrideWithValue(
            const AllocationPolicy(
              allow89ftFallback: true,
              reaperSharePreferred: 50,
              reaperShareMid: 40,
              reaperShareLow: 10,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final policy = container.read(allocationPolicyProvider);
      expect(policy.allow89ftFallback, isTrue);
      expect(policy.reaperSharePreferred, 50);
      expect(policy.reaperShareMid, 40);
      expect(policy.reaperShareLow, 10);
    });

    test('tax mode override propagates (No GST → 18%)', () {
      final container = ProviderContainer(
        overrides: [taxModeProvider.overrideWithValue(TaxMode.eighteen)],
      );
      addTearDown(container.dispose);

      final mode = container.read(taxModeProvider);
      expect(mode, TaxMode.eighteen);
      expect(mode.rate, Rational(BigInt.from(18), BigInt.from(100)));
    });

    test('loading policy override retunes the tiers for every reader', () {
      final retuned = LoadingPolicy(
        low: Money.fromRupees(120),
        high: Money.fromRupees(200),
        thresholdCft: Cft.fromInt(25),
      );
      final container = ProviderContainer(
        overrides: [loadingPolicyProvider.overrideWithValue(retuned)],
      );
      addTearDown(container.dispose);

      final loading = container.read(loadingPolicyProvider);
      expect(loading.low, Money.fromRupees(120));
      expect(loading.high, Money.fromRupees(200));
      expect(loading.thresholdCft, Cft.fromInt(25));
      // Below the new threshold → low tier; at the threshold → high tier.
      expect(loading.chargeFor(Cft.fromInt(20)), Money.fromRupees(120));
      expect(loading.chargeFor(Cft.fromInt(25)), Money.fromRupees(200));
    });
  });
}
