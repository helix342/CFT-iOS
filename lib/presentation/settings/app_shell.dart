/// The app shell: first-run gate + bottom-tab navigation (app-ux-revamp
/// Requirement 7).
///
/// Once first-run setup is complete, the app presents the four bottom tabs
/// Stock / Orders / Home / Bills, with **Home (the dashboard) as the default**
/// selected tab (Requirement 7.1, 6.1, OD-3). Settings is NOT a bottom tab; it
/// is reached from the top-right gear on the dashboard, which pushes the reused
/// `SettingsTab` (Requirement 7.2). Before setup is complete — a fresh install
/// with no seeded catalog and no business name — the shell shows
/// [FirstRunScreen] instead.
///
/// Each tab is a [CupertinoTabView] with its own navigator so pushed detail
/// screens stay within the tab (Requirement 7.6). The Stock tab lands on a hub
/// linking inventory browsing + receiving; the Orders tab hosts the unified
/// order workflow; the Home tab is the dashboard; the Bills tab lists finalized
/// invoices.
///
/// This shell installs [settingsPolicyOverrides] via [AppShell.rootOverrides]
/// at the app root so the editable policy controllers drive the task-15.1
/// policy providers for every reader.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wood_cft/presentation/bills/bills_list_screen.dart';
import 'package:wood_cft/presentation/home/dashboard_screen.dart';
import 'package:wood_cft/presentation/orders/orders_home_screen.dart';
import 'package:wood_cft/presentation/settings/first_run_providers.dart';
import 'package:wood_cft/presentation/settings/first_run_screen.dart';
import 'package:wood_cft/presentation/settings/settings_policy_controllers.dart';
import 'package:wood_cft/presentation/settings/settings_tab.dart';
import 'package:wood_cft/presentation/stock/inventory_browser_screen.dart';
import 'package:wood_cft/presentation/stock/receiving_screen.dart';

/// Routes between first-run setup and the main bottom-tab scaffold.
class AppShell extends ConsumerWidget {
  /// Creates the app shell.
  const AppShell({super.key});

  /// The `ProviderScope` overrides the app root should install so the editable
  /// Settings controllers drive the task-15.1 policy providers everywhere.
  static final rootOverrides = settingsPolicyOverrides;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstRun = ref.watch(firstRunCompleteProvider);

    return firstRun.when(
      loading: () => const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      ),
      error: (error, _) => CupertinoPageScaffold(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Could not start the app: $error'),
          ),
        ),
      ),
      data: (complete) =>
          complete ? const _MainTabs() : const FirstRunScreen(),
    );
  }
}

/// The four-tab bottom scaffold shown after first-run (Stock / Orders / Home /
/// Bills), with Home (dashboard) as the default tab.
class _MainTabs extends StatelessWidget {
  const _MainTabs();

  /// The Home (dashboard) tab index — the default landing tab (OD-3).
  static const int _homeTabIndex = 2;

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      controller: CupertinoTabController(initialIndex: _homeTabIndex),
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.cube_box),
            label: 'Stock',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.cart),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.doc_text),
            label: 'Bills',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            label: 'Settings',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return CupertinoTabView(builder: (_) => const _StockHub());
          case 1:
            return CupertinoTabView(builder: (_) => const OrdersHomeScreen());
          case 2:
            return CupertinoTabView(builder: (_) => const DashboardScreen());
          case 3:
            return CupertinoTabView(builder: (_) => const BillsListScreen());
          case 4:
          default:
            return CupertinoTabView(builder: (_) => const SettingsTab());
        }
      },
    );
  }
}

/// The Stock tab hub: links into the inventory browser and the receiving flow.
class _StockHub extends StatelessWidget {
  const _StockHub();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      key: const Key('tab_stock'),
      navigationBar: const CupertinoNavigationBar(middle: Text('Stock')),
      child: SafeArea(
        child: ListView(
          children: [
            _HubRow(
              key: const Key('stock_inventory_row'),
              label: 'Inventory',
              detail: 'Browse confirmed and pending stock',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const InventoryBrowserScreen(),
                ),
              ),
            ),
            _HubRow(
              key: const Key('stock_receive_row'),
              label: 'Receive stock',
              detail: 'Record a truck/inventory receipt',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const ReceivingScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tappable hub navigation row (label + one-line detail + chevron).
class _HubRow extends StatelessWidget {
  const _HubRow({
    required this.label,
    required this.detail,
    required this.onTap,
    super.key,
  });

  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.textStyle),
                  const SizedBox(height: 2),
                  Text(detail, style: theme.textTheme.tabLabelTextStyle),
                ],
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
