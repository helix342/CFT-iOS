/// The Home dashboard (app-ux-revamp Requirement 6).
///
/// The default landing tab after first-run (OD-3). It summarizes the business
/// at a glance from locally persisted data (Requirement 6.5): the CFT
/// Calculator brand mark + a top-right Settings gear that pushes the reused
/// `SettingsTab` (Requirement 6.7, 7.2), available confirmed stock per item
/// with explicit unit labels (Requirement 6.2), the all-time totals sold
/// (count + CFT + INR; Requirement 6.3), and the recent orders newest-first
/// (Requirement 6.4). Reads the aggregates through [dashboardSummaryProvider].
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wood_cft/application/receiving_service.dart';
import 'package:wood_cft/data/sales_query_dao.dart';
import 'package:wood_cft/domain/app_info.dart';
import 'package:wood_cft/presentation/orders/order_workflow_controller.dart';
import 'package:wood_cft/presentation/settings/business_profile_providers.dart' show appDatabaseProvider;

/// The computed dashboard summary, refreshed when the workflow state changes
/// (so returning after a sale reflects the new totals -- Requirement 6.6).
final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  ref.watch(orderWorkflowControllerProvider);
  await ReceivingService(ref.watch(appDatabaseProvider)).confirmAllPending();
  final dao = ref.watch(salesQueryDaoProvider);
  return dao.loadDashboard();
});

/// The Home dashboard screen.
class DashboardScreen extends ConsumerWidget {
  /// Creates the dashboard screen.
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);

    return CupertinoPageScaffold(
      key: const Key('tab_home'),
      navigationBar: CupertinoNavigationBar(
        leading: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Image.asset(kBrandAsset, key: const Key('dashboard_brand')),
        ),
        middle: const Text(kAppName),
      ),
      child: SafeArea(
        child: summary.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Could not load the dashboard: $e'),
            ),
          ),
          data: (data) => _DashboardBody(summary: data),
        ),
      ),
    );
  }
}



class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: ListView(
        key: const Key('dashboard_body'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Three summary tiles in a row: Total sold / Volume sold / Volume left.
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Total sold',
                  value: '${summary.totalPiecesSold}',
                  unit: 'pcs',
                  valueKey: const Key('dashboard_total_pieces'),
                  icon: CupertinoIcons.cube_box_fill,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Volume sold',
                  value: summary.totalCftSold.toFixed(),
                  unit: 'CFT',
                  valueKey: const Key('dashboard_total_cft'),
                  icon: CupertinoIcons.chart_bar_alt_fill,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Volume left',
                  value: summary.volumeLeft.toFixed(),
                  unit: 'CFT',
                  valueKey: const Key('dashboard_volume_left'),
                  icon: CupertinoIcons.tray_full_fill,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // The money total gets its own wide accent card.
          _AmountCard(amount: summary.totalAmount.format()),
          const _SectionLabel('Available stock'),
          if (summary.stock.isEmpty)
            const _EmptyCard(
              text: 'No stock on hand yet.',
              cardKey: Key('dashboard_stock_empty'),
            )
          else
            for (final s in summary.stock)
              _StockCard(
                key: Key(
                  'dashboard_stock_${s.varietyName}_${s.crossSectionLabel}_'
                  '${s.lengthFt}',
                ),
                stock: s,
              ),
          const _SectionLabel('Recent orders'),
          if (summary.recent.isEmpty)
            const _EmptyCard(
              text: 'No sales yet.',
              cardKey: Key('dashboard_recent_empty'),
            )
          else
            for (final r in summary.recent)
              _RecentCard(
                key: Key('dashboard_recent_${r.invoiceId}'),
                order: r,
              ),
        ],
      ),
    );
  }
}

/// Shared white card shell with rounded corners and a soft shadow.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// One of the three top summary tiles.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.valueKey,
    required this.icon,
  });

  final String label;
  final String value;
  final String unit;
  final Key valueKey;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.primaryColor),
          const SizedBox(height: 8),
          Text(
            value,
            key: valueKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.navTitleTextStyle.copyWith(fontSize: 20),
          ),
          Text(unit, style: theme.textTheme.tabLabelTextStyle),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.tabLabelTextStyle,
          ),
        ],
      ),
    );
  }
}

/// The wide money-total accent card.
class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: _Card(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.money_dollar_circle_fill,
                  color: theme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text('Total amount', style: theme.textTheme.textStyle),
              ],
            ),
            Text(
              amount,
              key: const Key('dashboard_total_amount'),
              style: theme.textTheme.navTitleTextStyle,
            ),
          ],
        ),
      ),
    );
  }
}

/// One available-stock SKU as its own card.
class _StockCard extends StatelessWidget {
  const _StockCard({required this.stock, super.key});

  final StockOnHand stock;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Card(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stock.varietyName,
                    style: theme.textTheme.textStyle
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stock.crossSectionLabel} \u00B7 ${stock.lengthFt} ft',
                    style: theme.textTheme.tabLabelTextStyle,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${stock.confirmedPieces} pcs',
                  style: theme.textTheme.textStyle
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${stock.availableCft.toFixed()} CFT',
                  style: theme.textTheme.tabLabelTextStyle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One recent order as its own card.
class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.order, super.key});

  final RecentOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final d = order.finalizedAt.toLocal();
    final date = '${d.year}-${_two(d.month)}-${_two(d.day)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Card(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.invoiceNumber,
                    style: theme.textTheme.textStyle
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.customerName ?? 'Walk-in \u00B7 $date',
                    style: theme.textTheme.tabLabelTextStyle,
                  ),
                ],
              ),
            ),
            Text(
              order.payable.format(),
              style: theme.textTheme.textStyle
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

/// An empty-state card used when a section has no data.
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text, required this.cardKey});

  final String text;
  final Key cardKey;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    return _Card(
      key: cardKey,
      child: Text(
        text,
        style: theme.textTheme.tabLabelTextStyle,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
      child: Text(
        text,
        style: CupertinoTheme.of(context)
            .textTheme
            .navTitleTextStyle
            .copyWith(fontSize: 16),
      ),
    );
  }
}
