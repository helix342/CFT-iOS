/// The Bills tab: local finalized invoices + read-only detail (app-ux-revamp
/// Requirement 7.5, 6.4).
///
/// Lists the locally persisted finalized `Invoices` newest-first (OD-8) so the
/// owner has a bill history before the Supabase backend exists. Tapping a bill
/// opens a read-only detail showing its lines and totals — nothing here mutates
/// stock or re-finalizes.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/domain/money.dart';
import 'package:wood_cft/presentation/orders/order_workflow_controller.dart';

/// The finalized invoices for the Bills list, newest-first. Refreshes when the
/// workflow state changes (so a new sale appears on return).
final finalizedInvoicesProvider = FutureProvider<List<InvoiceRow>>((ref) async {
  ref.watch(orderWorkflowControllerProvider);
  final dao = ref.watch(salesQueryDaoProvider);
  return dao.finalizedInvoices();
});

/// The lines of one invoice (read-only detail).
final invoiceLinesProvider =
    FutureProvider.family<List<InvoiceLineRow>, int>((ref, invoiceId) async {
  final dao = ref.watch(salesQueryDaoProvider);
  return dao.invoiceLines(invoiceId);
});

/// The Bills tab list screen.
class BillsListScreen extends ConsumerWidget {
  /// Creates the Bills list screen.
  const BillsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(finalizedInvoicesProvider);

    return CupertinoPageScaffold(
      key: const Key('tab_bills'),
      navigationBar: const CupertinoNavigationBar(middle: Text('Bills')),
      child: SafeArea(
        child: bills.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Could not load bills: $e'),
            ),
          ),
          data: (invoices) {
            if (invoices.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Text(
                  'No bills yet. Finalized orders appear here.',
                  key: Key('bills_empty'),
                ),
              );
            }
            return ListView.builder(
              key: const Key('bills_list'),
              itemCount: invoices.length,
              itemBuilder: (context, i) => _BillRow(
                key: Key('bill_${invoices[i].id}'),
                invoice: invoices[i],
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => BillDetailScreen(invoice: invoices[i]),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.invoice, required this.onTap, super.key});

  final InvoiceRow invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final d = invoice.finalizedAt.toLocal();
    final date = '${d.year}-${_two(d.month)}-${_two(d.day)}';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
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
                  Text(invoice.invoiceNumber, style: theme.textTheme.textStyle),
                  const SizedBox(height: 2),
                  Text(
                    invoice.customerName ?? date,
                    style: theme.textTheme.tabLabelTextStyle,
                  ),
                ],
              ),
            ),
            Text(
              Money.fromPaise(invoice.payablePaise).format(),
              style: theme.textTheme.textStyle,
            ),
            const SizedBox(width: 6),
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

  static String _two(int n) => n.toString().padLeft(2, '0');
}

/// The read-only detail for a single finalized bill.
class BillDetailScreen extends ConsumerWidget {
  /// Creates the bill detail screen for [invoice].
  const BillDetailScreen({required this.invoice, super.key});

  /// The finalized invoice being shown.
  final InvoiceRow invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = CupertinoTheme.of(context);
    final lines = ref.watch(invoiceLinesProvider(invoice.id));

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(invoice.invoiceNumber),
      ),
      child: SafeArea(
        child: ListView(
          key: const Key('bill_detail'),
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            lines.when(
              loading: () =>
                  const Center(child: CupertinoActivityIndicator()),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Could not load lines: $e'),
              ),
              data: (rows) => Column(
                children: [
                  for (final line in rows)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: CupertinoColors.separator
                                .resolveFrom(context),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${line.varietyName} · ${line.crossSectionLabel} '
                              '· ${line.lengthFt} ft · ${line.pieces} pcs',
                              style: theme.textTheme.textStyle,
                            ),
                          ),
                          Text(
                            Money.fromPaise(line.lineAmountPaise).format(),
                            style: theme.textTheme.textStyle,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Payable',
                    style: theme.textTheme.textStyle
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    Money.fromPaise(invoice.payablePaise).format(),
                    key: const Key('bill_detail_payable'),
                    style: theme.textTheme.navTitleTextStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
