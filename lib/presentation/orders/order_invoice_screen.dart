/// The Orders tab invoice / finalize step (app-ux-revamp Requirement 4.5-4.7).
///
/// Wires (does not rewrite) the reused `InvoicePreviewScreen` into the unified
/// workflow: it shows the bill the shared billing produced and offers a
/// "Mark sold" action that finalizes the approved order under the order-scoped
/// key, mirrors the invoice locally, and flips the draft to `sold`. On success
/// the issued invoice number is shown and a "Share bill" action marks the order
/// `shared`. A block (missing rate / insufficient stock / no session) keeps the
/// order resumable and surfaces the reason (Requirement 4.7).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wood_cft/application/finalize_service.dart';
import 'package:wood_cft/presentation/orders/order_build_providers.dart';
import 'package:wood_cft/presentation/orders/order_invoice_share.dart';
import 'package:wood_cft/presentation/orders/order_workflow_controller.dart';
import 'package:wood_cft/presentation/sell/invoice_preview_screen.dart';
import 'package:wood_cft/presentation/settings/business_profile_providers.dart';

/// The Orders invoice step hosting the reused invoice preview + finalize.
class OrderInvoiceScreen extends ConsumerWidget {
  /// Creates the invoice step.
  const OrderInvoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflow = ref.watch(orderWorkflowControllerProvider);
    final sold = workflow.step == OrderStep.sold ||
        workflow.step == OrderStep.shared;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Invoice')),
      child: SafeArea(
        child: Column(
          children: [
            const Expanded(child: InvoicePreviewScreen()),
            if (workflow.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  workflow.error!,
                  key: const Key('invoice_error'),
                  style: const TextStyle(color: CupertinoColors.systemRed),
                ),
              ),
            if (sold && workflow.invoiceNumber != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Sold · Invoice #${workflow.invoiceNumber}',
                  key: const Key('invoice_sold_banner'),
                ),
              ),
            _Footer(sold: sold, busy: workflow.busy),
          ],
        ),
      ),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({required this.sold, required this.busy});

  final bool sold;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: CupertinoColors.separator.resolveFrom(context)),
        ),
      ),
      child: sold
          ? _SoldActions(busy: busy)
          : Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    key: const Key('invoice_back'),
                    onPressed: busy
                        ? null
                        : () {
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
                    key: const Key('invoice_mark_sold'),
                    onPressed: busy ? null : () => _markSold(context, ref),
                    child: busy
                        ? const CupertinoActivityIndicator()
                        : const Text('Mark sold'),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _markSold(BuildContext context, WidgetRef ref) async {
    final allocation =
        await ref.read(stagedOrderAllocationProvider.future);
    if (allocation == null) return;
    await ref
        .read(orderWorkflowControllerProvider.notifier)
        .finalizeSold(allocation: allocation);
  }
}

/// The sold-order actions: the working Share/Copy buttons that build the
/// invoice snapshot from the finalized invoice and hand it to the share
/// coordinator, plus a Done action that marks the order `shared` and returns
/// home (FIX 3; Requirement 4.6).
class _SoldActions extends ConsumerWidget {
  const _SoldActions({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflow = ref.watch(orderWorkflowControllerProvider);
    final invoice = workflow.invoice;
    final profileAsync = ref.watch(businessProfileProvider);
    final ready = invoice != null && profileAsync.hasValue && !busy;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: CupertinoButton.filled(
            key: const Key('invoice_share_word'),
            onPressed: ready
                ? () => _share(context, ref, invoice, _ShareAction.word)
                : null,
            child: const Text('Share Word (.docx)'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            key: const Key('invoice_share_text'),
            onPressed: ready
                ? () => _share(context, ref, invoice, _ShareAction.text)
                : null,
            child: const Text('Share bill text (WhatsApp)'),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            key: const Key('invoice_copy_text'),
            onPressed: ready
                ? () => _share(context, ref, invoice, _ShareAction.copy)
                : null,
            child: const Text('Copy bill text'),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            key: const Key('invoice_done'),
            onPressed: busy ? null : () => _done(context, ref),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  Future<void> _share(
    BuildContext context,
    WidgetRef ref,
    FinalizedInvoice invoice,
    _ShareAction action,
  ) async {
    final business = ref.read(businessProfileProvider).value;
    if (business == null) return;
    final snapshot = buildInvoiceSnapshot(
      invoice: invoice,
      business: business,
    );
    final service = ref.read(invoiceShareServiceProvider);
    switch (action) {
      case _ShareAction.word:
        await service.shareInvoiceFile(snapshot);
      case _ShareAction.text:
        await service.shareBillText(snapshot);
      case _ShareAction.copy:
        await service.copyBillText(snapshot);
    }
    // Record that the finalized bill has been shared (never re-finalizes).
    await ref.read(orderWorkflowControllerProvider.notifier).share();
  }

  Future<void> _done(BuildContext context, WidgetRef ref) async {
    await ref.read(orderWorkflowControllerProvider.notifier).share();
    if (!context.mounted) return;
    // Returning to the Orders home completes the flow.
    Navigator.of(context).popUntil((r) => r.isFirst);
  }
}

/// Which share action a sold-order button triggers.
enum _ShareAction { word, text, copy }
