/// The Orders tab home: resumable saved orders + "New order" (app-ux-revamp
/// Requirement 4.3, 7.3).
///
/// Lists the saved orders still in `draft` / `review` / `approved` so the owner
/// can resume one later (Requirement 4.3), newest-updated first, each showing
/// its title/customer, status, and when it was last touched. A prominent "New
/// order" action starts a fresh workflow and opens the build screen.
///
/// Reads the resumable list through [resumableOrdersProvider]; resuming or
/// starting an order drives the [orderWorkflowControllerProvider] and pushes
/// the build screen within the Orders tab navigator.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/presentation/orders/order_build_screen.dart';
import 'package:wood_cft/presentation/orders/order_workflow_controller.dart';

/// The resumable saved orders (status in {draft, review, approved}),
/// newest-updated first.
final resumableOrdersProvider = FutureProvider<List<DraftOrderRow>>((ref) async {
  // Watch the workflow state so the list refreshes after save/sell.
  ref.watch(orderWorkflowControllerProvider);
  final dao = ref.watch(savedOrdersDaoProvider);
  return dao.loadResumable();
});

/// A short human label for an order status.
String statusLabel(DraftStatus status) => switch (status) {
      DraftStatus.draft => 'Draft',
      DraftStatus.preview => 'Draft',
      DraftStatus.review => 'In review',
      DraftStatus.approved => 'Approved',
      DraftStatus.sold => 'Sold',
      DraftStatus.shared => 'Shared',
    };

/// The Orders tab home screen.
class OrdersHomeScreen extends ConsumerWidget {
  /// Creates the Orders home screen.
  const OrdersHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumable = ref.watch(resumableOrdersProvider);

    return CupertinoPageScaffold(
      key: const Key('tab_orders'),
      navigationBar: const CupertinoNavigationBar(middle: Text('Orders')),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  key: const Key('new_order_button'),
                  onPressed: () => _startNewOrder(context, ref),
                  child: const Text('New order'),
                ),
              ),
            ),
            Expanded(
              child: resumable.when(
                loading: () => const Center(child: CupertinoActivityIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Could not load saved orders: $e'),
                  ),
                ),
                data: (orders) => _SavedOrdersList(
                  orders: orders,
                  onResume: (id) => _resumeOrder(context, ref, id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startNewOrder(BuildContext context, WidgetRef ref) async {
    await ref.read(orderWorkflowControllerProvider.notifier).startNewOrder();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => const OrderBuildScreen()),
    );
  }

  Future<void> _resumeOrder(
    BuildContext context,
    WidgetRef ref,
    int draftId,
  ) async {
    await ref.read(orderWorkflowControllerProvider.notifier).resume(draftId);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => const OrderBuildScreen()),
    );
  }
}

class _SavedOrdersList extends StatelessWidget {
  const _SavedOrdersList({required this.orders, required this.onResume});

  final List<DraftOrderRow> orders;
  final ValueChanged<int> onResume;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'No saved orders. Start a new order to begin.',
          key: Key('saved_orders_empty'),
        ),
      );
    }
    final theme = CupertinoTheme.of(context);
    return ListView.builder(
      key: const Key('saved_orders_list'),
      itemCount: orders.length,
      itemBuilder: (context, i) {
        final order = orders[i];
        final title = (order.title == null || order.title!.isEmpty)
            ? (order.customerName ?? 'Order #${order.id}')
            : order.title!;
        return GestureDetector(
          key: Key('saved_order_${order.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onResume(order.id),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
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
                      Text(title, style: theme.textTheme.textStyle),
                      const SizedBox(height: 2),
                      Text(
                        statusLabel(order.status),
                        style: theme.textTheme.tabLabelTextStyle,
                      ),
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
      },
    );
  }
}
