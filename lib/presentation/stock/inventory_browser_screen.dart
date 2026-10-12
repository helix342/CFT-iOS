/// The Stock-tab inventory browser UI (task 6.2).
///
/// Renders the filtered inventory produced by [InventoryQueryService]
/// (task 6.1) as a Cupertino list with:
///   * filter controls for variety, category, cross-section, and length
///     (Requirement 6.1), driven through [inventoryFilterProvider];
///   * a show/hide zero-stock toggle feeding `InventoryFilter.includeZeroStock`
///     (Requirement 6.4);
///   * per-item available quantity AND available CFT, each with an EXPLICIT
///     unit label — e.g. "30 pcs", "3 bunches", "2.5000 CFT" — never a bare
///     number (Requirements 6.2, 6.5, 17.6); reaper rows show the bunch count
///     with the piece-equivalent;
///   * pending-vs-confirmed badges — `Pending_Receiving_Stock` is shown as a
///     visibly distinct, text-and-icon badge, never sellable (Requirement
///     19.8, design.md -> Stock tab);
///   * a shortage (out-of-stock) cue that uses an icon + text, NEVER color
///     alone (Requirement 17.5);
///   * filtered totals for available CFT and pieces (Requirement 6.3).
///
/// Accessibility (Requirement 17.3, 17.4): interactive controls use ≥ 44×44 pt
/// hit targets and carry VoiceOver-friendly [Semantics] labels so quantity and
/// CFT are read with their units.
///
/// This widget is presentation-only: all querying, filtering, and CFT math
/// live behind the providers in `inventory_providers.dart` and the headless
/// `InventoryQueryService` / `CalculationService`.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wood_cft/application/inventory_query_service.dart';
import 'package:wood_cft/data/tables.dart' show CategoryKind;
import 'package:wood_cft/presentation/stock/inventory_providers.dart';

/// The minimum Apple-HIG touch-target size in logical points (Requirement
/// 17.3).
const double kMinTouchTarget = 44;

/// The inventory browser screen for the Stock tab.
class InventoryBrowserScreen extends ConsumerWidget {
  /// Creates the inventory browser screen.
  const InventoryBrowserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(inventoryQueryProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Inventory'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const _FilterBar(),
            const _ZeroStockToggleRow(),
            Expanded(
              child: result.when(
                data: (data) => _InventoryList(result: data),
                loading: () => const Center(
                  child: CupertinoActivityIndicator(),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Could not load inventory.\n$error',
                      textAlign: TextAlign.center,
                      style: CupertinoTheme.of(context).textTheme.textStyle,
                    ),
                  ),
                ),
              ),
            ),
            _TotalsFooter(result: result),
          ],
        ),
      ),
    );
  }
}

/// The row of filter controls (variety, category, cross-section, length).
class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(inventoryFilterProvider);
    final optionsAsync = ref.watch(inventoryFilterOptionsProvider);
    final options = optionsAsync.asData?.value;
    final notifier = ref.read(inventoryFilterProvider.notifier);

    final rows = options?.rows ?? const <InventoryRow>[];

    // Build the distinct option lists from the items that actually exist.
    final varieties = <int, String>{};
    final crossSections = <int, String>{};
    final lengths = <int>{};
    for (final r in rows) {
      varieties[r.varietyId] = r.varietyName;
      crossSections[r.crossSectionId] = r.crossSectionLabel;
      lengths.add(r.lengthFt);
    }
    final sortedLengths = lengths.toList()..sort();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              fieldKey: const Key('inventory_filter_variety'),
              label: 'Variety',
              value: filter.varietyId == null
                  ? null
                  : varieties[filter.varietyId],
              onTap: () => _pickVariety(context, varieties, notifier),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              fieldKey: const Key('inventory_filter_category'),
              label: 'Category',
              value: filter.category == null
                  ? null
                  : _categoryLabel(filter.category!),
              onTap: () => _pickCategory(context, notifier),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              fieldKey: const Key('inventory_filter_cross_section'),
              label: 'Size',
              value: filter.crossSectionId == null
                  ? null
                  : crossSections[filter.crossSectionId],
              onTap: () => _pickCrossSection(context, crossSections, notifier),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              fieldKey: const Key('inventory_filter_length'),
              label: 'Length',
              value: filter.lengthFt == null
                  ? null
                  : '${filter.lengthFt} ft',
              onTap: () => _pickLength(context, sortedLengths, notifier),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              key: const Key('inventory_filter_clear'),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
              onPressed: notifier.clearAll,
              child: const Text('Clear'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVariety(
    BuildContext context,
    Map<int, String> varieties,
    InventoryFilterNotifier notifier,
  ) async {
    await _showPicker<int?>(
      context: context,
      title: 'Filter by variety',
      options: [
        const _PickerOption<int?>(label: 'All varieties', value: null),
        for (final entry in varieties.entries)
          _PickerOption<int?>(label: entry.value, value: entry.key),
      ],
      onSelected: notifier.setVariety,
    );
  }

  Future<void> _pickCategory(
    BuildContext context,
    InventoryFilterNotifier notifier,
  ) async {
    await _showPicker<CategoryKind?>(
      context: context,
      title: 'Filter by category',
      options: const [
        _PickerOption<CategoryKind?>(label: 'All categories', value: null),
        _PickerOption<CategoryKind?>(
          label: 'Reaper',
          value: CategoryKind.reaper,
        ),
        _PickerOption<CategoryKind?>(label: 'Plank', value: CategoryKind.plank),
      ],
      onSelected: notifier.setCategory,
    );
  }

  Future<void> _pickCrossSection(
    BuildContext context,
    Map<int, String> crossSections,
    InventoryFilterNotifier notifier,
  ) async {
    await _showPicker<int?>(
      context: context,
      title: 'Filter by size',
      options: [
        const _PickerOption<int?>(label: 'All sizes', value: null),
        for (final entry in crossSections.entries)
          _PickerOption<int?>(label: entry.value, value: entry.key),
      ],
      onSelected: notifier.setCrossSection,
    );
  }

  Future<void> _pickLength(
    BuildContext context,
    List<int> lengths,
    InventoryFilterNotifier notifier,
  ) async {
    await _showPicker<int?>(
      context: context,
      title: 'Filter by length',
      options: [
        const _PickerOption<int?>(label: 'All lengths', value: null),
        for (final l in lengths)
          _PickerOption<int?>(label: '$l ft', value: l),
      ],
      onSelected: notifier.setLength,
    );
  }

  Future<void> _showPicker<T>({
    required BuildContext context,
    required String title,
    required List<_PickerOption<T>> options,
    required void Function(T value) onSelected,
  }) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(title),
        actions: [
          for (final option in options)
            CupertinoActionSheetAction(
              onPressed: () {
                onSelected(option.value);
                Navigator.of(sheetContext).pop();
              },
              child: Text(option.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: false,
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

/// The human-readable label for a cross-section [category].
String _categoryLabel(CategoryKind category) => switch (category) {
      CategoryKind.reaper => 'Reaper',
      CategoryKind.plank => 'Plank',
    };

/// One selectable value in a filter action sheet.
class _PickerOption<T> {
  const _PickerOption({required this.label, required this.value});
  final String label;
  final T value;
}

/// A single tappable filter control showing its label and current value.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final Key fieldKey;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final selected = value != null;
    return Semantics(
      button: true,
      label: selected ? '$label filter: $value' : '$label filter: all',
      child: CupertinoButton(
        key: fieldKey,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
        color: selected
            ? theme.primaryColor.withValues(alpha: 0.15)
            : CupertinoColors.tertiarySystemFill.resolveFrom(context),
        onPressed: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected ? '$label: $value' : label,
              style: theme.textTheme.textStyle.copyWith(
                fontSize: 15,
                color: selected
                    ? theme.primaryColor
                    : CupertinoColors.label.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              CupertinoIcons.chevron_down,
              size: 14,
              color: selected
                  ? theme.primaryColor
                  : CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// The show/hide zero-stock toggle row (Requirement 6.4).
class _ZeroStockToggleRow extends ConsumerWidget {
  const _ZeroStockToggleRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final includeZeroStock =
        ref.watch(inventoryFilterProvider).includeZeroStock;
    final notifier = ref.read(inventoryFilterProvider.notifier);
    final theme = CupertinoTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      constraints: const BoxConstraints(minHeight: kMinTouchTarget),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Show zero-stock items',
              style: theme.textTheme.textStyle,
            ),
          ),
          Semantics(
            label: 'Show zero-stock items',
            toggled: includeZeroStock,
            child: CupertinoSwitch(
              key: const Key('inventory_zero_stock_toggle'),
              value: includeZeroStock,
              onChanged: notifier.setIncludeZeroStock,
            ),
          ),
        ],
      ),
    );
  }
}

/// The scrollable list of inventory rows (or an empty-state message).
class _InventoryList extends StatelessWidget {
  const _InventoryList({required this.result});

  final InventoryQueryResult result;

  @override
  Widget build(BuildContext context) {
    if (result.rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No stock items match the current filter.',
            textAlign: TextAlign.center,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
          ),
        ),
      );
    }

    return ListView.separated(
      key: const Key('inventory_list'),
      itemCount: result.rows.length,
      separatorBuilder: (context, index) => Container(
        height: 0.5,
        color: CupertinoColors.separator.resolveFrom(context),
      ),
      itemBuilder: (context, index) =>
          _InventoryRowTile(row: result.rows[index]),
    );
  }
}

/// One inventory item: identity, quantity + CFT with explicit unit labels,
/// pending/confirmed badges, and a non-color shortage cue.
class _InventoryRowTile extends StatelessWidget {
  const _InventoryRowTile({required this.row});

  final InventoryRow row;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isReaper = row.category == CategoryKind.reaper;
    final qtyLabel = _availableQuantityLabel(row);
    final cftLabel = '${row.availableCft.toFixed()} CFT';
    final outOfStock = row.availablePieces == 0;

    final semanticsLabel = StringBuffer()
      ..write('${row.varietyName}, ${row.crossSectionLabel}, '
          '${row.lengthFt} feet. ')
      ..write(outOfStock ? 'Out of stock. ' : 'Available $qtyLabel. ')
      ..write('Available volume $cftLabel.');
    if (row.pendingPieces > 0) {
      semanticsLabel.write(
        ' Pending receiving ${row.pendingPieces} pieces, not yet sellable.',
      );
    }

    return Semantics(
      container: true,
      label: semanticsLabel.toString(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.varietyName,
                        style: theme.textTheme.textStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${row.crossSectionLabel}  ·  ${row.lengthFt} ft  ·  '
                        '${isReaper ? 'Reaper' : 'Plank'}',
                        style: theme.textTheme.tabLabelTextStyle.copyWith(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Quantity WITH an explicit unit label (Req 6.5, 17.6).
                    Text(
                      key: const Key('inventory_row_quantity'),
                      qtyLabel,
                      style: theme.textTheme.textStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // CFT WITH an explicit unit label (Req 6.5, 17.6).
                    Text(
                      key: const Key('inventory_row_cft'),
                      cftLabel,
                      style: theme.textTheme.tabLabelTextStyle.copyWith(
                        fontSize: 13,
                        color:
                            CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (outOfStock) const _ShortageBadge() else const _InStockBadge(),
                if (row.pendingPieces > 0)
                  _PendingBadge(pendingPieces: row.pendingPieces),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The available (confirmed) quantity with its explicit unit.
  ///
  /// Planks read "N pcs". Reapers trade in bunches of 10, so a reaper reads as
  /// its whole-bunch count with the piece-equivalent, e.g. "3 bunches (30 pcs)"
  /// (Requirements 3.1, 3.4, 6.5). A reaper whose confirmed pieces are not a
  /// whole number of bunches falls back to a piece count so no fictional bunch
  /// is implied.
  static String _availableQuantityLabel(InventoryRow row) {
    final pieces = row.availablePieces;
    if (row.category == CategoryKind.reaper) {
      const bunchSize = 10;
      if (pieces > 0 && pieces % bunchSize == 0) {
        final bunches = pieces ~/ bunchSize;
        final bunchWord = bunches == 1 ? 'bunch' : 'bunches';
        return '$bunches $bunchWord ($pieces pcs)';
      }
    }
    return '$pieces pcs';
  }
}

/// A neutral "confirmed / in stock" badge (text + icon, non-color).
class _InStockBadge extends StatelessWidget {
  const _InStockBadge();

  @override
  Widget build(BuildContext context) {
    return const _Badge(
      badgeKey: Key('inventory_confirmed_badge'),
      icon: CupertinoIcons.checkmark_seal,
      label: 'Confirmed',
      color: CupertinoColors.activeGreen,
    );
  }
}

/// A pending-receiving badge: visibly distinct, carries text + icon so it is
/// never color-only, and signals "not yet sellable" (Requirement 19.8).
class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.pendingPieces});

  final int pendingPieces;

  @override
  Widget build(BuildContext context) {
    return _Badge(
      badgeKey: const Key('inventory_pending_badge'),
      icon: CupertinoIcons.clock,
      label: 'Pending $pendingPieces pcs',
      color: CupertinoColors.systemOrange,
    );
  }
}

/// A non-color shortage cue: an icon AND the words "Out of stock", so the
/// shortage is never conveyed by color alone (Requirement 17.5).
class _ShortageBadge extends StatelessWidget {
  const _ShortageBadge();

  @override
  Widget build(BuildContext context) {
    return const _Badge(
      badgeKey: Key('inventory_shortage_indicator'),
      icon: CupertinoIcons.exclamationmark_triangle_fill,
      label: 'Out of stock',
      color: CupertinoColors.systemRed,
    );
  }
}

/// A small pill badge rendered as icon + text (never color-only).
class _Badge extends StatelessWidget {
  const _Badge({
    required this.badgeKey,
    required this.icon,
    required this.label,
    required this.color,
  });

  final Key badgeKey;
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final resolved = CupertinoDynamicColor.resolve(color, context);
    return Container(
      key: badgeKey,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: resolved.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: resolved),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: resolved,
            ),
          ),
        ],
      ),
    );
  }
}

/// The filtered-totals footer: available CFT + pieces across the active filter
/// (Requirement 6.3), each with an explicit unit label (Requirement 17.6).
class _TotalsFooter extends StatelessWidget {
  const _TotalsFooter({required this.result});

  final AsyncValue<InventoryQueryResult> result;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final data = result.asData?.value;
    final pieces = data?.totalAvailablePieces ?? 0;
    final cft = data?.totalAvailableCft.toFixed() ?? '0.0000';
    final pendingPieces = data?.totalPendingPieces ?? 0;

    return Container(
      key: const Key('inventory_totals'),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground
            .resolveFrom(context),
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available total',
                  style: theme.textTheme.tabLabelTextStyle.copyWith(
                    fontSize: 12,
                    color:
                        CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$pieces pcs',
                  style: theme.textTheme.textStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (pendingPieces > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Pending $pendingPieces pcs (not sellable)',
                      style: theme.textTheme.tabLabelTextStyle.copyWith(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '$cft CFT',
            style: theme.textTheme.navTitleTextStyle.copyWith(fontSize: 18),
          ),
        ],
      ),
    );
  }
}
