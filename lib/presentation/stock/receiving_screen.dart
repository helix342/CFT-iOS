/// The Stock-tab truck-receiving screen: compact length grid (task 5.2).
///
/// This is the receiving-session entry surface from design.md -> Screen Flows,
/// Stock tab -> "Receiving session". The owner:
///
///   1. selects a **variety** and a **cross-section**; the selection **stays
///      active across the whole grid** (Requirement 5.3), and
///   2. enters a quantity per **length 2â€“9 ft** on a **compact grid**
///      (Requirement 5.2). A reaper cross-section is entered in **bunches** and
///      the row shows its **piece-equivalent** (bunches Ã— 10) and per-line CFT;
///      a plank is entered in **pieces** (Requirements 5.4, 5.5). All CFT /
///      piece read-outs come from the single shared [CalculationService].
///
/// Committing a length row calls [ReceivingService.recordReceivingEntry] with a
/// freshly generated, stable idempotency key (one per committed entry), lands
/// the quantity as pending stock, and shows subtle inline feedback. The action
/// stays reachable with the numeric keyboard open (Requirement 10 usability).
///
/// SCOPE: this task builds the grid only. Session resume-after-restart (task
/// 5.3) and adjustment/undo (task 5.4) are separate tasks and are NOT built
/// here â€” there is deliberately no undo control on this screen.
///
/// Accessibility (Requirement 17.6): every tappable control is at least
/// 44 Ã— 44 pt, and every quantity and CFT value is shown with an explicit unit
/// label ("bunches", "pcs", "CFT") â€” never a bare number.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/application/receiving_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/presentation/common/quantity_stepper.dart';
import 'package:wood_cft/presentation/stock/receiving_providers.dart';

/// The minimum accessible touch-target size in logical pixels (Req 17.6).
const double kMinTouchTarget = 44;

/// The inclusive length range shown on the compact receiving grid (2â€“9 ft).
const List<int> kGridLengthsFt = [2, 3, 4, 5, 6, 7, 8, 9];

/// The compact length-grid receiving screen.
class ReceivingScreen extends ConsumerStatefulWidget {
  /// Creates the receiving screen.
  const ReceivingScreen({super.key});

  @override
  ConsumerState<ReceivingScreen> createState() => _ReceivingScreenState();
}

class _ReceivingScreenState extends ConsumerState<ReceivingScreen> {
  int? _selectedVarietyId;
  String? _selectedVarietyName;
  CrossSection? _selectedCrossSection;

  /// Monotonic counter folded into each committed entry's idempotency key so
  /// every commit carries a distinct, stable key (Req 5.9 exactly-once).
  int _commitSeq = 0;

  /// The most recent commit feedback shown inline under the grid.
  String? _feedback;

  @override
  Widget build(BuildContext context) {
    final varietiesAsync = ref.watch(receivingVarietiesProvider);
    final crossSectionsAsync = ref.watch(receivingCrossSectionsProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Receive stock'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            const _SectionLabel('Variety'),
            varietiesAsync.when(
              loading: () => const _LoadingRow(),
              error: (e, _) => _ErrorRow('Could not load varieties: $e'),
              data: (varieties) => _VarietyPicker(
                varieties: varieties,
                selectedId: _selectedVarietyId,
                onSelected: (row) => setState(() {
                  _selectedVarietyId = row.id;
                  _selectedVarietyName = row.name;
                  _feedback = null;
                }),
              ),
            ),
            const SizedBox(height: 16),
            const _SectionLabel('Cross-section'),
            crossSectionsAsync.when(
              loading: () => const _LoadingRow(),
              error: (e, _) => _ErrorRow('Could not load cross-sections: $e'),
              data: (crossSections) => _CrossSectionPicker(
                crossSections: crossSections,
                selectedId: _selectedCrossSection?.id,
                onSelected: (cs) => setState(() {
                  _selectedCrossSection = cs;
                  _feedback = null;
                }),
              ),
            ),
            const SizedBox(height: 24),
            _buildGridSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildGridSection(BuildContext context) {
    final variety = _selectedVarietyId;
    final crossSection = _selectedCrossSection;
    if (variety == null || crossSection == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Select a variety and a cross-section to begin receiving.',
          key: Key('receiving_grid_hint'),
        ),
      );
    }

    final isReaper = crossSection.category == WoodCategory.reaper;
    final unitWord = isReaper ? 'bunches' : 'pieces';

    return Column(
      key: const Key('receiving_grid'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            // The active selection persists across every length row (Req 5.3).
            'Lengths 2â€“9 ft Â· ${_selectedVarietyName ?? ''} Â· '
            '${crossSection.inchLabel} Â· enter $unitWord',
            key: const Key('receiving_grid_subtitle'),
          ),
        ),
        const SizedBox(height: 8),
        for (final lengthFt in kGridLengthsFt)
          _LengthRow(
            key: Key('length_row_$lengthFt'),
            lengthFt: lengthFt,
            crossSection: crossSection,
            isReaper: isReaper,
            calc: ref.watch(calculationServiceProvider),
            onCommit: (qty) => _commitEntry(
              varietyId: variety,
              crossSection: crossSection,
              lengthFt: lengthFt,
              qtyInput: qty,
              isReaper: isReaper,
            ),
          ),
        if (_feedback != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              _feedback!,
              key: const Key('receiving_feedback'),
              style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle,
            ),
          ),
      ],
    );
  }

  Future<void> _commitEntry({
    required int varietyId,
    required CrossSection crossSection,
    required int lengthFt,
    required int qtyInput,
    required bool isReaper,
  }) async {
    final service = ref.read(receivingServiceProvider);
    final key = StockItemKey(
      varietyId: varietyId,
      crossSectionId: crossSection.id,
      lengthFt: lengthFt,
    );
    final stockItem = await ref.read(stockItemLookupProvider(key).future);
    if (stockItem == null) {
      if (!mounted) return;
      setState(() => _feedback = 'No stock item for $lengthFt ft; '
          'cannot receive.');
      return;
    }

    // A fresh, stable idempotency key per committed entry (Req 5.9).
    _commitSeq += 1;
    final idempotencyKey =
        'recv:$varietyId:${crossSection.id}:$lengthFt:'
        '${DateTime.now().microsecondsSinceEpoch}:$_commitSeq';

    final unit = isReaper ? InputUnit.bunch : InputUnit.piece;
    final result = await service.recordReceivingEntry(
      stockItemId: stockItem.id,
      crossSection: crossSection,
      qtyInput: qtyInput,
      unit: unit,
      idempotencyKey: idempotencyKey,
      // No pending state in this single-device app: received stock is
      // confirmed immediately so it shows as available in Inventory at once.
      syncState: SyncState.confirmed,
    );

    if (!mounted) return;
    final unitWord = isReaper ? 'bunches' : 'pcs';
    final piecesWord = '${result.piecesDelta} pcs';
    setState(() {
      _feedback = result.outcome == ReceivingOutcome.recorded
          ? 'Received $qtyInput $unitWord ($piecesWord) at $lengthFt ft '
              'â€” pending.'
          : 'Already recorded at $lengthFt ft.';
    });
  }
}

/// A horizontally scrollable set of variety choices (selection persists).
class _VarietyPicker extends StatelessWidget {
  const _VarietyPicker({
    required this.varieties,
    required this.selectedId,
    required this.onSelected,
  });

  final List<WoodVarietyRow> varieties;
  final int? selectedId;
  final ValueChanged<WoodVarietyRow> onSelected;

  @override
  Widget build(BuildContext context) {
    if (varieties.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('No active varieties.'),
      );
    }
    return SizedBox(
      height: kMinTouchTarget + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: varieties.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final v = varieties[i];
          return _ChoiceChip(
            key: Key('variety_choice_${v.id}'),
            label: v.name,
            selected: v.id == selectedId,
            onTap: () => onSelected(v),
          );
        },
      ),
    );
  }
}

/// A horizontally scrollable set of cross-section choices (selection persists).
class _CrossSectionPicker extends StatelessWidget {
  const _CrossSectionPicker({
    required this.crossSections,
    required this.selectedId,
    required this.onSelected,
  });

  final List<CrossSection> crossSections;
  final int? selectedId;
  final ValueChanged<CrossSection> onSelected;

  @override
  Widget build(BuildContext context) {
    if (crossSections.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('No active cross-sections.'),
      );
    }
    return SizedBox(
      height: kMinTouchTarget + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: crossSections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cs = crossSections[i];
          final kind = cs.category == WoodCategory.reaper ? 'Reaper' : 'Plank';
          return _ChoiceChip(
            key: Key('cross_section_choice_${cs.id}'),
            label: '${cs.inchLabel} Â· $kind',
            selected: cs.id == selectedId,
            onTap: () => onSelected(cs),
          );
        },
      ),
    );
  }
}

/// A single length row of the compact grid: a labelled numeric field, a live
/// piece-equivalent + CFT read-out (with explicit unit labels), and a 44Ã—44
/// commit button that stays reachable with the keyboard open.
class _LengthRow extends StatefulWidget {
  const _LengthRow({
    required this.lengthFt,
    required this.crossSection,
    required this.isReaper,
    required this.calc,
    required this.onCommit,
    super.key,
  });

  final int lengthFt;
  final CrossSection crossSection;
  final bool isReaper;
  final CalculationService calc;
  final Future<void> Function(int qtyInput) onCommit;

  @override
  State<_LengthRow> createState() => _LengthRowState();
}

class _LengthRowState extends State<_LengthRow> {
  /// The draft count for this length, adjusted via the shared stepper. Zero
  /// means "nothing staged" so the add action is disabled.
  int _count = 0;
  bool _committing = false;

  int? get _qty => _count > 0 ? _count : null;

  @override
  Widget build(BuildContext context) {
    final qty = _qty;
    final unitWord = widget.isReaper ? 'bunches' : 'pcs';

    // Live read-out: piece-equivalent (reaper) + line CFT, from the shared
    // engine. Always shown with explicit unit labels, never a bare number.
    String readout;
    if (qty == null) {
      readout = 'Enter $unitWord';
    } else {
      final pieces = widget.isReaper
          ? widget.calc.pieceEquivalent(widget.crossSection, qty)
          : qty;
      final lineCft =
          widget.calc.lineCftFor(widget.crossSection, widget.lengthFt, pieces);
      final perUnitCft = widget.isReaper
          ? widget.calc.cftPerBunch(widget.crossSection, widget.lengthFt)
          : widget.calc.cftPerPiece(widget.crossSection, widget.lengthFt);
      final perUnitWord = widget.isReaper ? 'CFT/bunch' : 'CFT/pc';
      readout = widget.isReaper
          ? '$pieces pcs Â· ${lineCft.toFixed(4)} CFT Â· '
              '${perUnitCft.toFixed(4)} $perUnitWord'
          : '${lineCft.toFixed(4)} CFT Â· ${perUnitCft.toFixed(4)} $perUnitWord';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '${widget.lengthFt} ft',
              key: Key('length_label_${widget.lengthFt}'),
              style: CupertinoTheme.of(context).textTheme.textStyle,
            ),
          ),
          const SizedBox(width: 8),
          QuantityStepper(
            key: Key('qty_stepper_${widget.lengthFt}'),
            value: _count,
            unitLabel: unitWord,
            onChanged: (v) => setState(() => _count = v),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              readout,
              key: Key('readout_${widget.lengthFt}'),
              style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle,
            ),
          ),
          const SizedBox(width: 8),
          _CommitButton(
            key: Key('commit_${widget.lengthFt}'),
            enabled: qty != null && !_committing,
            onPressed: qty == null ? null : () => _commit(qty),
          ),
        ],
      ),
    );
  }

  Future<void> _commit(int qty) async {
    setState(() => _committing = true);
    try {
      await widget.onCommit(qty);
      if (!mounted) return;
      setState(() => _count = 0);
    } finally {
      if (mounted) setState(() => _committing = false);
    }
  }
}

/// A 44Ã—44 add button so the commit action meets the touch-target rule and
/// stays reachable with the numeric keyboard open (Req 17.6, usability).
class _CommitButton extends StatelessWidget {
  const _CommitButton({
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kMinTouchTarget,
      height: kMinTouchTarget,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: enabled ? onPressed : null,
        child: const Icon(
          CupertinoIcons.tray_arrow_down,
          semanticLabel: 'Add to inventory',
        ),
      ),
    );
  }
}

/// A selectable chip whose tappable area is at least 44Ã—44 (Req 17.6).
class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final color = selected ? theme.primaryColor : theme.barBackgroundColor;
    final textColor =
        selected ? CupertinoColors.white : theme.textTheme.textStyle.color;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
      onPressed: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: kMinTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: CupertinoColors.separator),
        ),
        child: Text(
          label,
          style: theme.textTheme.textStyle.copyWith(color: textColor),
        ),
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: CupertinoActivityIndicator(),
      );
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(message),
      );
}
