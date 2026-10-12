/// The Settings -> "Price matrix" screen (task 7.2; vertical layout per
/// app-ux-revamp Requirement 5).
///
/// A vertically-scrolling list of ₹/CFT rate rows — one row per variety ×
/// cross-section — grouped under a per-variety header, over the stored rates
/// (design.md -> Screen Flows, Settings: "price matrix (editable grid with
/// visible missing-rate markers)"; Req 4.3). It replaces the former
/// horizontally-scrolling grid; the providers, missing-rate marker, editor,
/// and persistence are preserved unchanged. Each row:
///
///   * shows the stored rate formatted in ₹, or a VISIBLE missing marker — an
///     icon plus the word "Missing" — on every unpriced cell (Req 4.5). The cue
///     is textual + iconographic, never colour alone (design.md -> accessibility
///     17.5 spirit);
///   * opens an editor on tap where the owner types a rupee amount (up to two
///     decimals, parsed to an exact `Rational`) to set the rate, or clears it
///     back to missing.
///
/// Pricing is NOT forced. Receiving is allowed before any rate exists
/// (Req 4.6 / 17.13), so this screen never blocks and leaving every cell blank
/// is a valid state. Flagging a missing rate during SELLING (Req 17.14) is a
/// separate surface handled by the order-entry/billing tasks.
///
/// The grid is wired to `PricingService` through [priceMatrixProvider]; it
/// reuses the shared `appDatabaseProvider` and holds no price logic of its own.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/presentation/settings/price_matrix_providers.dart';
import 'package:wood_cft/presentation/settings/rate_format.dart';

/// Editable price-matrix grid, wired via Riverpod to `PricingService`.
class PriceMatrixScreen extends ConsumerWidget {
  /// Creates the price-matrix screen.
  const PriceMatrixScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMatrix = ref.watch(priceMatrixProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Price matrix'),
      ),
      child: SafeArea(
        child: asyncMatrix.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Could not load the price matrix: $error'),
            ),
          ),
          data: (matrix) => _MatrixBody(matrix: matrix),
        ),
      ),
    );
  }
}

class _MatrixBody extends ConsumerWidget {
  const _MatrixBody({required this.matrix});

  final PriceMatrix matrix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (matrix.varieties.isEmpty || matrix.crossSections.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Add varieties and cross-sections to price them here.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final theme = CupertinoTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Rates are ₹ per CFT, GST-exclusive. Tap a cell to set or clear a '
            'rate. Leaving a cell blank is fine — you can receive stock before '
            'prices are set.',
            style: theme.textTheme.tabLabelTextStyle,
          ),
        ),
        if (matrix.missingCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              key: const Key('price_matrix_missing_summary'),
              children: [
                const Icon(
                  CupertinoIcons.exclamationmark_circle,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${matrix.missingCount} rate'
                    '${matrix.missingCount == 1 ? '' : 's'} missing',
                    style: theme.textTheme.textStyle,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            key: const Key('price_matrix_list'),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // One grouped section per variety; one vertical rate row per
              // cross-section underneath it (Requirement 5.1).
              for (final variety in matrix.varieties) ...[
                _VarietyHeader(name: variety.name),
                for (final crossSection in matrix.crossSections)
                  _RateRow(
                    variety: variety,
                    crossSection: crossSection,
                    cell: matrix.cell(variety.id, crossSection.id),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A per-variety group header above its rate rows.
class _VarietyHeader extends StatelessWidget {
  const _VarietyHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      alignment: Alignment.centerLeft,
      child: Text(
        name,
        style: theme.textTheme.textStyle.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// A single tappable vertical rate row: the cross-section label on the left and
/// the ₹ rate (or a visible missing marker) on the right.
class _RateRow extends ConsumerWidget {
  const _RateRow({
    required this.variety,
    required this.crossSection,
    required this.cell,
  });

  final WoodVariety variety;
  final CrossSection crossSection;
  final PriceMatrixCell cell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = CupertinoTheme.of(context);
    final cellKey = Key('price_cell_${variety.id}_${crossSection.id}');

    final Widget valueContent;
    if (cell.isMissing) {
      // Visible missing marker: icon + text, never colour alone (Req 4.5).
      valueContent = Row(
        key: Key('price_missing_${variety.id}_${crossSection.id}'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle,
            size: 16,
            semanticLabel: 'Missing rate',
          ),
          const SizedBox(width: 4),
          Text('Missing', style: theme.textTheme.tabLabelTextStyle),
        ],
      );
    } else {
      valueContent = Text(
        '₹${formatRate(cell.rate!)}',
        key: Key('price_value_${variety.id}_${crossSection.id}'),
        style: theme.textTheme.textStyle,
        textAlign: TextAlign.right,
      );
    }

    return GestureDetector(
      key: cellKey,
      onTap: () => _editCell(context, ref),
      behavior: HitTestBehavior.opaque,
      child: Container(
        // Minimum 44×44 pt touch target (Req 5.3 / accessibility 17.3).
        constraints: const BoxConstraints(minHeight: 48),
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
              child: Text(
                crossSection.inchLabel,
                style: theme.textTheme.textStyle,
              ),
            ),
            const SizedBox(width: 12),
            valueContent,
            const SizedBox(width: 8),
            const Icon(
              CupertinoIcons.chevron_forward,
              size: 16,
              color: CupertinoColors.systemGrey,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCell(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: cell.rate == null ? '' : formatRate(cell.rate!),
    );
    final result = await showCupertinoDialog<_RateEditResult>(
      context: context,
      builder: (dialogContext) => _RateEditorDialog(
        variety: variety,
        crossSection: crossSection,
        controller: controller,
        canClear: !cell.isMissing,
      ),
    );
    controller.dispose();
    if (result == null) return;

    final notifier = ref.read(priceMatrixProvider.notifier);
    switch (result.action) {
      case _RateEditAction.save:
        await notifier.setRate(
          varietyId: variety.id,
          crossSectionId: crossSection.id,
          rate: result.rate!,
        );
      case _RateEditAction.clear:
        await notifier.clearRate(
          varietyId: variety.id,
          crossSectionId: crossSection.id,
        );
    }
  }
}

enum _RateEditAction { save, clear }

class _RateEditResult {
  const _RateEditResult.save(this.rate) : action = _RateEditAction.save;
  const _RateEditResult.clear()
      : action = _RateEditAction.clear,
        rate = null;

  final _RateEditAction action;
  final Rational? rate;
}

/// The rate editor shown when a cell is tapped: enter a rupee amount, save it,
/// or clear it back to missing.
class _RateEditorDialog extends StatefulWidget {
  const _RateEditorDialog({
    required this.variety,
    required this.crossSection,
    required this.controller,
    required this.canClear,
  });

  final WoodVariety variety;
  final CrossSection crossSection;
  final TextEditingController controller;
  final bool canClear;

  @override
  State<_RateEditorDialog> createState() => _RateEditorDialogState();
}

class _RateEditorDialogState extends State<_RateEditorDialog> {
  String? _error;

  void _onSave() {
    final Rational rate;
    try {
      rate = parseRateInput(widget.controller.text);
    } on RateInputError catch (e) {
      setState(() => _error = e.message);
      return;
    }
    Navigator.of(context).pop(_RateEditResult.save(rate));
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text('${widget.variety.name} · ${widget.crossSection.inchLabel}'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Rate in ₹ per CFT (GST-exclusive)'),
            const SizedBox(height: 8),
            CupertinoTextField(
              key: const Key('price_editor_field'),
              controller: widget.controller,
              autofocus: true,
              placeholder: 'e.g. 150.75',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              prefix: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text('₹'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                key: const Key('price_editor_error'),
                style: const TextStyle(
                  color: CupertinoColors.systemRed,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          key: const Key('price_editor_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (widget.canClear)
          CupertinoDialogAction(
            key: const Key('price_editor_clear'),
            isDestructiveAction: true,
            onPressed: () =>
                Navigator.of(context).pop(const _RateEditResult.clear()),
            child: const Text('Clear'),
          ),
        CupertinoDialogAction(
          key: const Key('price_editor_save'),
          isDefaultAction: true,
          onPressed: _onSave,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
