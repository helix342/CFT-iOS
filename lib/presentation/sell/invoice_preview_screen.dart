/// The Sell-tab **invoice preview + finalize** screen (task 11.5).
///
/// This is the "Invoice preview" / "Finalize" surface from design.md -> Screen
/// Flows -> Sell tab. It renders the invoice the shared calculation produced
/// from the current draft's allocation + the policy singletons, and gates the
/// FINALIZE action exactly as the design's flow does:
///
///   * **The bill** — one goods row per sold line (variety + SKU label +
///     length, allocated pieces, exact CFT, ₹/CFT rate, line amount), the goods
///     subtotal, the **single** tax line (never a CGST/SGST split), the loading
///     charge, and the payable grand total, all from
///     `BillingService.computeTotals` via `invoicePreviewProvider`
///     (Requirement 12.2).
///   * **Draft never mutates stock** — a banner states explicitly that a
///     preview is a draft and writes nothing to inventory until finalize
///     (Requirement 12.1, 12.5, 21.21). Building/viewing the preview deducts
///     NO stock.
///   * **Missing-rate flag** — a sold line with no rate is flagged inline and
///     blocks finalize (Requirement 4.7, 17.14).
///   * **Gated FINALIZE** — the button is DISABLED, with a clear reason, when
///     the order is empty, when signed out ([FinalizeGateReason.notAuthenticated]),
///     when offline ([FinalizeGateReason.offline]), when any line is missing a
///     rate, or when confirmed stock is insufficient (Requirements 12.2, 12.3b,
///     4.7, 12.6). The reason text names what to fix and makes clear the order
///     simply stays a draft.
///   * **Issued invoice number** — on a successful finalize the screen shows
///     the permanent invoice number returned by `FinalizeService` (Requirement
///     12.2).
///   * **Blocked finalize** — if the service refuses (a
///     [FinalizeBlockedException] reason or a `NotAuthenticatedException`), the
///     screen surfaces that reason clearly and the order stays a draft.
///
/// Accessibility (Requirements 17.3, 17.5, 17.6): amounts and quantities carry
/// explicit unit labels, the missing-rate / blocked cues are icon + text (never
/// colour alone), and the finalize status is announced via [Semantics].
///
/// This widget is presentation-only: the preview, the gate, and the finalize
/// attempt all live behind the providers in `invoice_preview_providers.dart`
/// and the headless `BillingService` / `FinalizeService`.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/application/finalize_service.dart';
import 'package:wood_cft/domain/cft.dart';
import 'package:wood_cft/presentation/sell/invoice_preview_providers.dart';

/// The minimum Apple-HIG touch-target size in logical points (Requirement
/// 17.3).
const double kMinTouchTarget = 44;

/// The Sell-tab invoice preview + finalize screen.
class InvoicePreviewScreen extends ConsumerWidget {
  /// Creates the invoice preview screen.
  const InvoicePreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewAsync = ref.watch(invoicePreviewProvider);
    final finalizeState = ref.watch(finalizeControllerProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Invoice preview'),
      ),
      child: SafeArea(
        child: previewAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => _ErrorState(message: '$error'),
          data: (preview) {
            if (preview == null) {
              return const _EmptyState();
            }
            return _PreviewBody(
              preview: preview,
              finalizeState: finalizeState,
            );
          },
        ),
      ),
    );
  }
}

/// Empty-draft state: nothing staged, nothing to preview.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No order lines to bill yet. Build the order first.',
          key: const Key('invoice_preview_empty'),
          textAlign: TextAlign.center,
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
        ),
      ),
    );
  }
}

/// Surfaces a preview-build error.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Could not build the invoice preview.\n$message',
          key: const Key('invoice_preview_error'),
          textAlign: TextAlign.center,
          style: CupertinoTheme.of(context).textTheme.textStyle,
        ),
      ),
    );
  }
}

/// The scrollable preview: the draft/no-mutation banner, the goods lines, the
/// totals block, the finalize gate/result, and the FINALIZE button.
class _PreviewBody extends ConsumerWidget {
  const _PreviewBody({required this.preview, required this.finalizeState});

  final InvoicePreview preview;
  final FinalizeState finalizeState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      key: const Key('invoice_preview_list'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        const _DraftBanner(),
        if (preview.isPartial) const _PartialBanner(),
        for (var i = 0; i < preview.lines.length; i++)
          _GoodsLineRow(index: i, line: preview.lines[i]),
        _TotalsBlock(totals: preview.totals),
        const SizedBox(height: 8),
        if (finalizeState.isSuccess)
          _IssuedInvoiceBanner(invoice: finalizeState.invoice!)
        else ...[
          if (finalizeState.error != null)
            _BlockedBanner(reason: finalizeState.error!),
          if (preview.gate != null)
            _GateReasonBanner(reason: preview.gate!),
          _FinalizeButton(
            enabled: preview.canFinalize && !finalizeState.inProgress,
            inProgress: finalizeState.inProgress,
            onPressed: () =>
                ref.read(finalizeControllerProvider.notifier).finalize(),
          ),
        ],
      ],
    );
  }
}

/// The explicit "a preview is a draft and never mutates stock" banner
/// (Requirement 12.1, 12.5, 21.21).
class _DraftBanner extends StatelessWidget {
  const _DraftBanner();

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final resolved = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Container(
      key: const Key('invoice_preview_draft_banner'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Semantics(
        container: true,
        label: 'This is a draft preview. It does not change stock until you '
            'finalize.',
        child: Row(
          children: [
            Icon(CupertinoIcons.doc_text, size: 18, color: resolved),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Draft preview — no stock is deducted until you finalize.',
                style: theme.textTheme.textStyle
                    .copyWith(fontSize: 13, color: resolved),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A partial-allocation banner so an understocked order is never shown as a
/// clean fill in the bill (Requirement 8.4).
class _PartialBanner extends StatelessWidget {
  const _PartialBanner();

  @override
  Widget build(BuildContext context) {
    final resolved = CupertinoDynamicColor.resolve(
      CupertinoColors.systemOrange,
      context,
    );
    return Container(
      key: const Key('invoice_preview_partial_banner'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: resolved.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.exclamationmark_triangle_fill,
              size: 18, color: resolved),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'PARTIAL — some lines could not be fully met from confirmed '
              'stock.',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: resolved,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single goods line in the bill, with a missing-rate flag when unpriced.
class _GoodsLineRow extends StatelessWidget {
  const _GoodsLineRow({required this.index, required this.line});

  final int index;
  final InvoicePreviewLine line;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final labelStyle = theme.textTheme.tabLabelTextStyle.copyWith(
      fontSize: 13,
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );
    final cft = Cft(line.cft).toFixed();
    final rateText =
        line.rate == null ? '—' : '₹${line.rate!.toDouble().toStringAsFixed(2)}';
    final amountText = line.amount?.format() ?? '—';

    return Container(
      key: Key('invoice_line_$index'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground
            .resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${line.varietyName} · ${line.label} · ${line.lengthFt} ft',
                  key: Key('invoice_line_${index}_sku'),
                  style: theme.textTheme.textStyle
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                amountText,
                key: Key('invoice_line_${index}_amount'),
                style: theme.textTheme.textStyle
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${line.pieces} pcs · $cft CFT · $rateText / CFT',
            key: Key('invoice_line_${index}_detail'),
            style: labelStyle,
          ),
          if (!line.hasRate) ...[
            const SizedBox(height: 6),
            _MissingRateFlag(index: index),
          ],
        ],
      ),
    );
  }
}

/// The inline missing-rate flag on a line (icon + text, Requirement 4.7,
/// 17.14).
class _MissingRateFlag extends StatelessWidget {
  const _MissingRateFlag({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final resolved = CupertinoDynamicColor.resolve(
      CupertinoColors.systemOrange,
      context,
    );
    return Row(
      key: Key('invoice_line_${index}_missing_rate'),
      children: [
        Icon(CupertinoIcons.exclamationmark_triangle_fill,
            size: 14, color: resolved),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Missing rate — set a price for this item to finalize.',
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: resolved,
                ),
          ),
        ),
      ],
    );
  }
}

/// The totals block: goods subtotal, the single tax line, loading, and payable.
class _TotalsBlock extends StatelessWidget {
  const _TotalsBlock({required this.totals});

  final InvoiceTotals totals;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('invoice_preview_totals'),
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground
            .resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          _TotalRow(
            label: 'Goods subtotal',
            value: totals.goodsSubtotal.format(),
            valueKey: const Key('invoice_total_goods'),
          ),
          _TotalRow(
            label: totals.taxLabel,
            value: totals.tax.format(),
            valueKey: const Key('invoice_total_tax'),
          ),
          _TotalRow(
            label: 'Loading',
            value: totals.loading.format(),
            valueKey: const Key('invoice_total_loading'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: _Divider(),
          ),
          _TotalRow(
            label: 'Payable',
            value: totals.payable.format(),
            valueKey: const Key('invoice_total_payable'),
            emphasise: true,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      color: CupertinoColors.separator.resolveFrom(context),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    required this.valueKey,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final Key valueKey;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final style = emphasise
        ? theme.textTheme.navTitleTextStyle.copyWith(fontSize: 17)
        : theme.textTheme.textStyle;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: emphasise
                  ? style.copyWith(fontWeight: FontWeight.w700)
                  : style.copyWith(
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
            ),
          ),
          Text(value, key: valueKey, style: style),
        ],
      ),
    );
  }
}

/// The green issued-invoice banner shown after a successful finalize
/// (Requirement 12.2).
class _IssuedInvoiceBanner extends StatelessWidget {
  const _IssuedInvoiceBanner({required this.invoice});

  final FinalizedInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final resolved =
        CupertinoDynamicColor.resolve(CupertinoColors.activeGreen, context);
    final number = invoice.number;
    return Container(
      key: const Key('invoice_finalized_banner'),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: resolved.withValues(alpha: 0.5)),
      ),
      child: Semantics(
        container: true,
        label: 'Invoice finalized. Invoice number $number issued.',
        child: Row(
          children: [
            Icon(CupertinoIcons.checkmark_seal_fill, size: 20, color: resolved),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoice finalized',
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .textStyle
                        .copyWith(fontWeight: FontWeight.w700, color: resolved),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Invoice #$number',
                    key: const Key('invoice_finalized_number'),
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .textStyle
                        .copyWith(color: resolved),
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

/// The banner surfacing a service-level block (the FinalizeBlockedException
/// reason or a not-authenticated message), shown after a failed attempt.
class _BlockedBanner extends StatelessWidget {
  const _BlockedBanner({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final resolved =
        CupertinoDynamicColor.resolve(CupertinoColors.systemRed, context);
    return Container(
      key: const Key('invoice_blocked_banner'),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: resolved.withValues(alpha: 0.5)),
      ),
      child: Semantics(
        container: true,
        label: 'Finalize blocked. $reason. The order stays a draft.',
        child: Row(
          children: [
            Icon(CupertinoIcons.xmark_octagon_fill, size: 18, color: resolved),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Finalize blocked — $reason',
                key: const Key('invoice_blocked_reason'),
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: resolved,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The advisory gate banner explaining why FINALIZE is disabled right now, in
/// the design's gate order (Requirements 4.7, 12.2, 12.3b, 12.6).
class _GateReasonBanner extends StatelessWidget {
  const _GateReasonBanner({required this.reason});

  final FinalizeGateReason reason;

  @override
  Widget build(BuildContext context) {
    final resolved = CupertinoDynamicColor.resolve(
      CupertinoColors.systemOrange,
      context,
    );
    return Container(
      key: const Key('invoice_gate_banner'),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: resolved.withValues(alpha: 0.5)),
      ),
      child: Semantics(
        container: true,
        label: 'Finalize unavailable. ${_message(reason)}',
        child: Row(
          children: [
            Icon(CupertinoIcons.info_circle_fill, size: 18, color: resolved),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _message(reason),
                key: const Key('invoice_gate_reason'),
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: resolved,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _message(FinalizeGateReason reason) => switch (reason) {
        FinalizeGateReason.emptyOrder =>
          'Nothing to finalize — no stock allocated.',
        FinalizeGateReason.notAuthenticated =>
          'Sign in to finalize. The order stays a draft until you do.',
        FinalizeGateReason.offline =>
          'You are offline. Finalizing needs connectivity — the order stays '
              'a draft until you reconnect.',
        FinalizeGateReason.missingRate =>
          'A line is missing a rate. Set a price for every item to finalize.',
        FinalizeGateReason.insufficientStock =>
          'Not enough confirmed stock to cover every line. The order stays a '
              'draft.',
      };
}

/// The gated FINALIZE button: a prominent filled Cupertino button that is
/// disabled (greyed, non-tappable) when the gate blocks it or a finalize is in
/// progress.
class _FinalizeButton extends StatelessWidget {
  const _FinalizeButton({
    required this.enabled,
    required this.inProgress,
    required this.onPressed,
  });

  final bool enabled;
  final bool inProgress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          key: const Key('invoice_finalize_button'),
          minimumSize: const Size(double.infinity, kMinTouchTarget),
          onPressed: enabled ? onPressed : null,
          child: inProgress
              ? const CupertinoActivityIndicator()
              : const Text('FINALIZE'),
        ),
      ),
    );
  }
}
