/// The Settings tab surface (task 15.2).
///
/// A Cupertino settings page that lets the owner view and edit the app-wide
/// configuration (design.md -> Screen Flows, Settings; Requirements 17.8,
/// 17.10, 17.11, 17.12):
///
///   * **Business profile** — a link into [BusinessProfileScreen] (name,
///     address, phone, GSTIN, invoice prefix — task 13.1).
///   * **Price matrix** — a link into [PriceMatrixScreen] (task 7.2).
///   * **Tax mode** — an editable segmented selector (No GST / 9% / 18%),
///     driving [taxModeControllerProvider] so the choice flows to billing
///     (Requirements 10.1, 10.5). Always a single literal tax line.
///   * **Loading policy** — the two tiers surfaced for the owner to read and
///     confirm (₹100 below 20 CFT, ₹150 at or above 20 CFT inclusive — CD-6).
///   * **Allocation knobs** — the 8–9 ft fallback toggle (default OFF — OD-5)
///     and the reaper 60/30/10 length-group shares, driving
///     [allocationPolicyControllerProvider].
///
/// Edits are wired through the editable controllers in
/// `settings_policy_controllers.dart`; the read-only task-15.1 policy providers
/// are overridden against those controllers at the app root, so a change here
/// propagates to every billing/allocation reader without redefining the policy
/// providers. The shared `appDatabaseProvider` backs the linked screens and is
/// never redeclared.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/presentation/settings/business_profile_screen.dart';
import 'package:wood_cft/presentation/settings/policy_providers.dart';
import 'package:wood_cft/presentation/settings/price_matrix_screen.dart';
import 'package:wood_cft/presentation/settings/settings_policy_controllers.dart';

/// The Settings tab, wired via Riverpod to the policy controllers and the
/// business/price screens.
class SettingsTab extends ConsumerWidget {
  /// Creates the Settings tab.
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taxMode = ref.watch(taxModeProvider);
    final loading = ref.watch(loadingPolicyProvider);
    final allocation = ref.watch(allocationPolicyProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Settings'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            const _SectionHeader('Business'),
            _NavRow(
              key: const Key('settings_business_profile_row'),
              label: 'Business profile',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const BusinessProfileScreen(),
                ),
              ),
            ),
            _NavRow(
              key: const Key('settings_price_matrix_row'),
              label: 'Price matrix',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const PriceMatrixScreen(),
                ),
              ),
            ),
            const _SectionHeader('Tax'),
            _TaxModeRow(selected: taxMode),
            const _SectionHeader('Loading charge'),
            _LoadingPolicyView(policy: loading),
            const _SectionHeader('Allocation'),
            _AllocationFallbackRow(enabled: allocation.allow89ftFallback),
            _ReaperSharesView(policy: allocation),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// A grouped section header.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: CupertinoTheme.of(context)
            .textTheme
            .tabLabelTextStyle
            .copyWith(letterSpacing: 0.5),
      ),
    );
  }
}

/// A tappable navigation row that pushes a detail screen.
class _NavRow extends StatelessWidget {
  const _NavRow({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: CupertinoColors.separator.resolveFrom(context),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: CupertinoTheme.of(context).textTheme.textStyle,
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_forward,
              size: 18,
              color: CupertinoColors.systemGrey,
            ),
          ],
        ),
      ),
    );
  }
}

/// The editable single-line tax-mode selector (No GST / 9% / 18%).
class _TaxModeRow extends ConsumerWidget {
  const _TaxModeRow({required this.selected});

  final TaxMode selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A single literal tax line — never a CGST/SGST split.',
            style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: CupertinoSegmentedControl<TaxMode>(
              key: const Key('settings_tax_mode_control'),
              groupValue: selected,
              children: const {
                TaxMode.noGst: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text('No GST'),
                ),
                TaxMode.nine: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text('9%'),
                ),
                TaxMode.eighteen: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text('18%'),
                ),
              },
              onValueChanged: (mode) =>
                  ref.read(taxModeControllerProvider.notifier).set(mode),
            ),
          ),
        ],
      ),
    );
  }
}

/// A read/confirm view of the two loading tiers.
class _LoadingPolicyView extends StatelessWidget {
  const _LoadingPolicyView({required this.policy});

  final LoadingPolicy policy;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A flat charge added once per order after tax.',
            style: theme.textTheme.tabLabelTextStyle,
          ),
          const SizedBox(height: 8),
          Text(
            'Below ${policy.thresholdCft.toFixed(0)} CFT: '
            '${policy.low.format()}',
            key: const Key('settings_loading_low'),
            style: theme.textTheme.textStyle,
          ),
          const SizedBox(height: 4),
          Text(
            '${policy.thresholdInclusive ? 'At or above' : 'Above'} '
            '${policy.thresholdCft.toFixed(0)} CFT: ${policy.high.format()}',
            key: const Key('settings_loading_high'),
            style: theme.textTheme.textStyle,
          ),
        ],
      ),
    );
  }
}

/// The 8–9 ft fallback toggle, driving the allocation controller.
class _AllocationFallbackRow extends ConsumerWidget {
  const _AllocationFallbackRow({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = CupertinoTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Allow 8–9 ft fallback',
                    style: theme.textTheme.textStyle),
                const SizedBox(height: 2),
                Text(
                  'When off, flexible reaper allocation excludes 8–9 ft.',
                  style: theme.textTheme.tabLabelTextStyle,
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            key: const Key('settings_allow_89ft_switch'),
            value: enabled,
            onChanged: (value) => ref
                .read(allocationPolicyControllerProvider.notifier)
                .setAllow89ftFallback(value),
          ),
        ],
      ),
    );
  }
}

/// A read view of the reaper 60/30/10 length-group shares.
class _ReaperSharesView extends StatelessWidget {
  const _ReaperSharesView({required this.policy});

  final AllocationPolicy policy;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reaper length-group shares',
              style: theme.textTheme.textStyle),
          const SizedBox(height: 4),
          Text(
            '{6,7} ft: ${policy.reaperSharePreferred}% · '
            '{3,4,5} ft: ${policy.reaperShareMid}% · '
            '{2} ft: ${policy.reaperShareLow}%',
            key: const Key('settings_reaper_shares'),
            style: theme.textTheme.tabLabelTextStyle,
          ),
        ],
      ),
    );
  }
}
