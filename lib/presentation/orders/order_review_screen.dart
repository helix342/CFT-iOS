/// The Orders tab review step (app-ux-revamp Requirement 4.1).
///
/// Wires (does not rewrite) the reused `AllocationReviewScreen` into the
/// unified workflow: it shows the picking list the shared allocator produced
/// for the staged order, with a footer offering Back, Save-for-later, and a
/// Next action that approves the allocation and advances to the invoice step.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wood_cft/presentation/orders/order_build_providers.dart';
import 'package:wood_cft/presentation/orders/order_invoice_screen.dart';
import 'package:wood_cft/presentation/orders/order_workflow_controller.dart';
import 'package:wood_cft/presentation/sell/allocation_review_screen.dart';

/// The Orders review step hosting the reused allocation review.
class OrderReviewScreen extends ConsumerWidget {
  /// Creates the review step.
  const OrderReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Review order')),
      child: SafeArea(
        child: Column(
          children: [
            const Expanded(child: AllocationReviewScreen()),
            const _ReviewAmountSummary(),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: CupertinoColors.separator.resolveFrom(context),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      key: const Key('review_back'),
                      onPressed: () {
                        ref
                            .read(orderWorkflowControllerProvider.notifier)
                            .back();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoButton.filled(
                      key: const Key('review_approve'),
                      onPressed: () => _approve(context, ref),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    await ref.read(orderWorkflowControllerProvider.notifier).approve();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => const OrderInvoiceScreen()),
    );
  }
}

/// A small goods-total ₹ summary above the review footer (FIX 5).
///
/// Surfaces the goods amount the reviewed allocation will bill (exact
/// allocated CFT × stored rate, summed per line via `BillingService`), reading
/// rates through the shared `PricingService`. The reused
/// [AllocationReviewScreen] is left untouched; this only adds the ₹ total.
class _ReviewAmountSummary extends ConsumerWidget {
  const _ReviewAmountSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amountAsync = ref.watch(stagedOrderReviewAmountProvider);
    final theme = CupertinoTheme.of(context);

    final (text, note) = amountAsync.when(
      loading: () => ('…', null),
      error: (_, _) => ('—', null),
      data: (r) => (
        r.total.format(),
        r.anyUnpriced ? 'Some lines are unpriced' : null,
      ),
    );

    return Container(
      key: const Key('review_amount_summary'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Goods total',
            style:
                theme.textTheme.textStyle.copyWith(fontWeight: FontWeight.w600),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                text,
                key: const Key('review_amount_value'),
                style: theme.textTheme.textStyle
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              if (note != null)
                Text(
                  note,
                  style: theme.textTheme.tabLabelTextStyle.copyWith(
                    color: CupertinoColors.systemOrange.resolveFrom(context),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
