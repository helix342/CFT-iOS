/// The adjustable staged-order-lines view (app-ux-revamp Requirement 3).
///
/// Renders each staged line with its variety, cross-section, length, unit
/// count, and EXACT CFT (4-dp display of the exact value from the shared
/// `CalculationService`), alongside a shared [QuantityStepper] to raise or
/// lower the quantity in place (Requirement 3.1, 3.2). Decrementing a line to
/// zero removes it (Requirement 3.4). A footer shows the running total exact
/// CFT across all staged lines and updates as lines change (Requirement 3.5).
///
/// It is presentation-only: it reads [stagedOrderLinesProvider] and reports
/// changes back through the notifier, holding no line state of its own.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wood_cft/presentation/common/quantity_stepper.dart';
import 'package:wood_cft/presentation/orders/order_build_providers.dart';
import 'package:wood_cft/presentation/orders/staged_order_line.dart';

/// A list of adjustable staged order lines with a running-total CFT footer.
class StagedOrderLinesView extends ConsumerWidget {
  /// Creates the staged-lines view.
  const StagedOrderLinesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = CupertinoTheme.of(context);
    final lines = ref.watch(stagedOrderLinesProvider);
    final calc = ref.watch(orderBuildCalculationProvider);
    final notifier = ref.read(stagedOrderLinesProvider.notifier);

    if (lines.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Text(
          'No lines yet. Add items to build the order.',
          key: Key('staged_lines_empty'),
        ),
      );
    }

    final total = ref.watch(stagedOrderTotalCftProvider);
    final amountAsync = ref.watch(stagedOrderTotalAmountProvider);

    return Column(
      key: const Key('staged_lines'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < lines.length; i++)
          _StagedLineRow(
            key: Key('staged_line_$i'),
            index: i,
            line: lines[i],
            cftText: calc
                .lineCftFor(
                  lines[i].crossSection,
                  lines[i].lengthFt,
                  lines[i].pieces,
                )
                .toFixed(),
            onChanged: (v) => notifier.setQuantityAt(i, v),
          ),
        Container(
          key: const Key('staged_lines_total'),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: CupertinoColors.separator.resolveFrom(context),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: theme.textTheme.textStyle
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${total.toFixed()} CFT',
                    style: theme.textTheme.textStyle
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Amount',
                    style: theme.textTheme.textStyle
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    amountAsync.when(
                      loading: () => '…',
                      error: (_, _) => '—',
                      data: (r) => r.total.format(),
                    ),
                    key: const Key('staged_lines_total_amount'),
                    style: theme.textTheme.textStyle
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single adjustable staged line: identity + exact CFT + ₹ rate + line
/// amount + a quantity stepper (Requirement 3; FIX 5).
class _StagedLineRow extends ConsumerWidget {
  const _StagedLineRow({
    required this.index,
    required this.line,
    required this.cftText,
    required this.onChanged,
    super.key,
  });

  final int index;
  final StagedOrderLine line;
  final String cftText;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = CupertinoTheme.of(context);
    final priceAsync = ref.watch(stagedLinePriceProvider(line));

    // The ₹/CFT rate and the computed line amount (FIX 5). Both read through
    // the shared PricingService / BillingService so they match billing exactly.
    final rateText = priceAsync.when(
      loading: () => '…',
      error: (_, _) => '—',
      data: (p) => p.rate == null
          ? 'no rate'
          : '\u20B9${p.rate!.toDouble().toStringAsFixed(2)}/CFT',
    );
    final amountText = priceAsync.when(
      loading: () => '…',
      error: (_, _) => '—',
      data: (p) => p.amount?.format() ?? '—',
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${line.varietyName} · ${line.crossSection.inchLabel} '
                        '· ${line.lengthFt} ft',
                        style: theme.textTheme.textStyle,
                      ),
                    ),
                    Text(
                      amountText,
                      key: Key('staged_line_amount_$index'),
                      style: theme.textTheme.textStyle
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  // Exact 4-dp CFT from the shared engine (Req 3.1, 3.3) plus
                  // the unit count and the ₹/CFT rate (FIX 5).
                  '$cftText CFT · ${line.quantityUnits} ${line.unitLabel} · '
                  '$rateText',
                  key: Key('staged_line_cft_$index'),
                  style: theme.textTheme.tabLabelTextStyle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          QuantityStepper(
            key: Key('staged_line_stepper_$index'),
            value: line.quantityUnits,
            unitLabel: line.unitLabel,
            // minValue 0 so a decrement from 1 removes the line (Req 3.4).
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
