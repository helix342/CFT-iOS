/// The Orders tab order-build screen (app-ux-revamp Requirement 3, 4.1, 7).
///
/// Lets the owner add ANY of the four structured request shapes to the current
/// order with a segmented control (mirroring the Sell-tab order entry):
///
///   1. **Exact qty** — a fully pinned SKU (variety + cross-section + length +
///      whole-unit quantity). Added as an adjustable [StagedOrderLine] the
///      owner tunes in place with the shared +/- [QuantityStepper]
///      (Requirement 3).
///   2. **Target CFT · length** — variety + cross-section + length + a target
///      CFT. Added as a [StagedTargetRequest] (no stepper; allocation decides
///      units).
///   3. **Target CFT · cross-section** — variety + cross-section + a target CFT,
///      lengths flexible.
///   4. **Target CFT · category** — variety + category (reaper or plank) + a
///      target CFT, cross-section and lengths flexible.
///
/// When a cross-section + length are chosen the form shows the EXACT CFT of one
/// piece (and, for a reaper, one bunch) from the single shared
/// `CalculationService` so the owner sees the per-unit volume before adding
/// (Requirement 2). Each staged exact-qty line keeps its exact line CFT via
/// [StagedOrderLinesView]; staged target requests are listed with their target
/// CFT and a remove control.
///
/// Moving to review syncs the staged exact lines AND target requests into the
/// shared `draftOrderRequestsProvider` as their REAL `OrderRequest` subtypes so
/// the reused `AllocationReviewScreen` and `InvoicePreviewScreen` (wired, not
/// rewritten) run the shared allocator over the true request shapes.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/presentation/common/quantity_stepper.dart';
import 'package:wood_cft/presentation/orders/order_build_providers.dart';
import 'package:wood_cft/presentation/orders/order_review_screen.dart';
import 'package:wood_cft/presentation/orders/order_workflow_controller.dart';
import 'package:wood_cft/presentation/orders/staged_order_line.dart';
import 'package:wood_cft/presentation/orders/staged_order_lines_view.dart';
import 'package:wood_cft/presentation/orders/staged_target_request.dart';
import 'package:wood_cft/presentation/sell/sell_providers.dart';

/// The minimum accessible touch-target size in logical pixels.
const double kBuildMinTouchTarget = 44;

/// The length choices offered for an added line (2-9 ft).
const List<int> kBuildLengthsFt = [2, 3, 4, 5, 6, 7, 8, 9];

/// The four structured request shapes, in the order shown on the segmented
/// control.
enum _BuildFormKind {
  exactQty,
  targetCftFixedLength,
  targetCftFlexCrossSection,
  targetCftFlexCategory;

  /// The short segmented-control label for this shape.
  String get shortLabel => switch (this) {
        _BuildFormKind.exactQty => 'Exact qty',
        _BuildFormKind.targetCftFixedLength => 'CFT · length',
        _BuildFormKind.targetCftFlexCrossSection => 'CFT · section',
        _BuildFormKind.targetCftFlexCategory => 'CFT · category',
      };
}

/// The Orders tab build screen.
class OrderBuildScreen extends ConsumerStatefulWidget {
  /// Creates the order-build screen.
  const OrderBuildScreen({super.key});

  @override
  ConsumerState<OrderBuildScreen> createState() => _OrderBuildScreenState();
}

class _OrderBuildScreenState extends ConsumerState<OrderBuildScreen> {
  _BuildFormKind _kind = _BuildFormKind.exactQty;

  int? _varietyId;
  String? _varietyName;
  CrossSection? _crossSection;
  WoodCategory? _category;
  int? _lengthFt;
  int _qty = 1;

  final TextEditingController _targetCftController = TextEditingController();

  String? _feedback;

  @override
  void dispose() {
    _targetCftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final varietiesAsync = ref.watch(sellVarietiesProvider);
    final crossSectionsAsync = ref.watch(sellCrossSectionsProvider);
    final lines = ref.watch(stagedOrderLinesProvider);
    final targets = ref.watch(stagedTargetRequestsProvider);

    final needsCrossSection = _kind != _BuildFormKind.targetCftFlexCategory;
    final needsCategory = _kind == _BuildFormKind.targetCftFlexCategory;
    final needsLength = _kind == _BuildFormKind.exactQty ||
        _kind == _BuildFormKind.targetCftFixedLength;
    final needsQuantity = _kind == _BuildFormKind.exactQty;
    final needsTargetCft = _kind != _BuildFormKind.exactQty;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Build order')),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  const _Label('Request type'),
                  _RequestTypePicker(
                    kind: _kind,
                    onChanged: (k) => setState(() {
                      _kind = k;
                      _feedback = null;
                    }),
                  ),
                  const _Label('Variety'),
                  varietiesAsync.when(
                    loading: () => const _Loading(),
                    error: (e, _) => _ErrorText('Varieties: $e'),
                    data: (varieties) => _ChoiceRow(
                      children: [
                        for (final v in varieties)
                          _Chip(
                            key: Key('build_variety_${v.id}'),
                            label: v.name,
                            selected: v.id == _varietyId,
                            onTap: () => setState(() {
                              _varietyId = v.id;
                              _varietyName = v.name;
                              _feedback = null;
                            }),
                          ),
                      ],
                    ),
                  ),
                  if (needsCrossSection) ...[
                    const _Label('Cross-section'),
                    crossSectionsAsync.when(
                      loading: () => const _Loading(),
                      error: (e, _) => _ErrorText('Cross-sections: $e'),
                      data: (crossSections) => _ChoiceRow(
                        children: [
                          for (final cs in crossSections)
                            _Chip(
                              key: Key('build_cs_${cs.id}'),
                              label: cs.inchLabel,
                              selected: cs.id == _crossSection?.id,
                              onTap: () => setState(() {
                                _crossSection = cs;
                                _feedback = null;
                              }),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (needsCategory) ...[
                    const _Label('Category'),
                    _ChoiceRow(
                      children: [
                        for (final c in WoodCategory.values)
                          _Chip(
                            key: Key('build_category_${c.name}'),
                            label: c == WoodCategory.reaper
                                ? 'Reaper'
                                : 'Plank',
                            selected: c == _category,
                            onTap: () => setState(() {
                              _category = c;
                              _feedback = null;
                            }),
                          ),
                      ],
                    ),
                  ],
                  if (needsLength) ...[
                    const _Label('Length'),
                    _ChoiceRow(
                      children: [
                        for (final l in kBuildLengthsFt)
                          _Chip(
                            key: Key('build_length_$l'),
                            label: '$l ft',
                            selected: l == _lengthFt,
                            onTap: () => setState(() {
                              _lengthFt = l;
                              _feedback = null;
                            }),
                          ),
                      ],
                    ),
                  ],
                  if (needsCrossSection && needsLength) _CftPerPieceReadout(
                    varietyId: _varietyId,
                    crossSection: _crossSection,
                    lengthFt: _lengthFt,
                  ),
                  if (needsQuantity) ...[
                    const _Label('Quantity'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          QuantityStepper(
                            key: const Key('build_qty_stepper'),
                            value: _qty,
                            unitLabel: _crossSection?.category ==
                                    WoodCategory.reaper
                                ? 'bunches'
                                : 'pcs',
                            minValue: 1,
                            onChanged: (v) => setState(() => _qty = v),
                          ),
                          const Spacer(),
                          CupertinoButton.filled(
                            key: const Key('build_add_line'),
                            onPressed: _addExactLine,
                            child: const Text('Add line'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (needsTargetCft) ...[
                    const _Label('Target CFT (meet or exceed)'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: CupertinoTextField(
                        key: const Key('build_target_cft_field'),
                        controller: _targetCftController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: false,
                        ),
                        placeholder: 'CFT',
                        suffix: const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Text('CFT'),
                        ),
                        onChanged: (_) => setState(() => _feedback = null),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: CupertinoButton.filled(
                          key: const Key('build_add_target'),
                          onPressed: _addTargetRequest,
                          child: const Text('Add to order'),
                        ),
                      ),
                    ),
                  ],
                  if (_feedback != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        _feedback!,
                        key: const Key('build_feedback'),
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .tabLabelTextStyle,
                      ),
                    ),
                  const SizedBox(height: 16),
                  const _Label('Order lines'),
                  const StagedOrderLinesView(),
                  _StagedTargetList(
                    targets: targets,
                    onRemove: (i) => ref
                        .read(stagedTargetRequestsProvider.notifier)
                        .removeAt(i),
                  ),
                ],
              ),
            ),
            _Footer(
              canContinue: lines.isNotEmpty || targets.isNotEmpty,
              onSaveForLater: _saveForLater,
              onContinue: _continueToReview,
            ),
          ],
        ),
      ),
    );
  }

  void _addExactLine() {
    final varietyId = _varietyId;
    final cs = _crossSection;
    final lengthFt = _lengthFt;
    if (varietyId == null) {
      setState(() => _feedback = 'Select a variety first.');
      return;
    }
    if (cs == null) {
      setState(() => _feedback = 'Select a cross-section.');
      return;
    }
    if (lengthFt == null) {
      setState(() => _feedback = 'Select a length.');
      return;
    }
    ref.read(stagedOrderLinesProvider.notifier).addLine(
          StagedOrderLine(
            varietyId: varietyId,
            varietyName: _varietyName ?? 'Variety #$varietyId',
            crossSection: cs,
            lengthFt: lengthFt,
            quantityUnits: _qty,
          ),
        );
    setState(() {
      _qty = 1;
      _feedback = 'Added exact-qty line to the order.';
    });
  }

  void _addTargetRequest() {
    final varietyId = _varietyId;
    if (varietyId == null) {
      setState(() => _feedback = 'Select a variety first.');
      return;
    }

    final target = _parseTargetCft();
    if (target == null) return;

    final StagedTargetRequest request;
    switch (_kind) {
      case _BuildFormKind.exactQty:
        return;
      case _BuildFormKind.targetCftFixedLength:
        final cs = _crossSection;
        final lengthFt = _lengthFt;
        if (cs == null) {
          setState(() => _feedback = 'Select a cross-section.');
          return;
        }
        if (lengthFt == null) {
          setState(() => _feedback = 'Select a length.');
          return;
        }
        request = StagedTargetRequest(
          kind: StagedTargetKind.fixedLength,
          varietyId: varietyId,
          varietyName: _varietyName ?? 'Variety #$varietyId',
          crossSection: cs,
          lengthFt: lengthFt,
          targetCft: target,
        );
      case _BuildFormKind.targetCftFlexCrossSection:
        final cs = _crossSection;
        if (cs == null) {
          setState(() => _feedback = 'Select a cross-section.');
          return;
        }
        request = StagedTargetRequest(
          kind: StagedTargetKind.flexCrossSection,
          varietyId: varietyId,
          varietyName: _varietyName ?? 'Variety #$varietyId',
          crossSection: cs,
          targetCft: target,
        );
      case _BuildFormKind.targetCftFlexCategory:
        final category = _category;
        if (category == null) {
          setState(() => _feedback = 'Select a category.');
          return;
        }
        request = StagedTargetRequest(
          kind: StagedTargetKind.flexCategory,
          varietyId: varietyId,
          varietyName: _varietyName ?? 'Variety #$varietyId',
          category: category,
          targetCft: target,
        );
    }

    ref.read(stagedTargetRequestsProvider.notifier).add(request);
    setState(() {
      _targetCftController.clear();
      _feedback = 'Added ${_kind.shortLabel} line to the order.';
    });
  }

  /// Parses the target-CFT field into a strictly positive [Rational], setting
  /// inline feedback and returning null on any invalid input.
  Rational? _parseTargetCft() {
    final text = _targetCftController.text.trim();
    if (text.isEmpty) {
      setState(() => _feedback = 'Enter a target CFT.');
      return null;
    }
    final Rational value;
    try {
      value = Rational.parse(text);
    } on FormatException {
      setState(() => _feedback = 'Target CFT must be a number.');
      return null;
    }
    if (value <= Rational.zero) {
      setState(() => _feedback = 'Target CFT must be greater than zero.');
      return null;
    }
    return value;
  }

  Future<void> _saveForLater() async {
    await ref.read(orderWorkflowControllerProvider.notifier).saveForLater();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _continueToReview() async {
    // Sync the staged exact lines AND target requests into the shared
    // draft-request store (as their real OrderRequest subtypes) so the reused
    // allocation-review + invoice-preview surfaces operate on this order.
    final requests = ref.read(stagedOrderRequestsProvider);
    final draft = ref.read(draftOrderRequestsProvider.notifier);
    draft.clear();
    for (final r in requests) {
      draft.add(r);
    }
    await ref.read(orderWorkflowControllerProvider.notifier).review();
    if (!mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => const OrderReviewScreen()),
    );
  }
}

/// The segmented control that picks one of the four request shapes.
class _RequestTypePicker extends StatelessWidget {
  const _RequestTypePicker({required this.kind, required this.onChanged});

  final _BuildFormKind kind;
  final ValueChanged<_BuildFormKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<_BuildFormKind>(
          key: const Key('build_request_type_segments'),
          groupValue: kind,
          onValueChanged: (k) {
            if (k != null) onChanged(k);
          },
          children: {
            for (final k in _BuildFormKind.values)
              k: Padding(
                key: Key('build_request_type_${k.name}'),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Text(
                  k.shortLabel,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          },
        ),
      ),
    );
  }
}

/// Shows the exact CFT of one piece (and, for a reaper, one bunch) of the
/// currently chosen cross-section + length (Requirement 2).
class _CftPerPieceReadout extends ConsumerWidget {
  const _CftPerPieceReadout({
    required this.varietyId,
    required this.crossSection,
    required this.lengthFt,
  });

  final int? varietyId;
  final CrossSection? crossSection;
  final int? lengthFt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = crossSection;
    final length = lengthFt;
    if (cs == null || length == null) {
      return const SizedBox.shrink();
    }
    final calc = ref.watch(orderBuildCalculationProvider);
    final perPiece = calc.cftPerPiece(cs, length).toFixed();
    final isReaper = cs.category == WoodCategory.reaper;
    final perBunch =
        isReaper ? calc.cftPerBunch(cs, length).toFixed() : null;
    final theme = CupertinoTheme.of(context);

    // Also surface the ₹/CFT rate for the current selection (FIX 5) when a
    // variety is chosen, so the owner sees the price before adding the line.
    final vid = varietyId;
    final rateAsync = vid == null
        ? null
        : ref.watch(
            buildSelectionRateProvider(
              (varietyId: vid, crossSectionId: cs.id),
            ),
          );
    final rateText = rateAsync?.when(
      loading: () => null,
      error: (_, _) => null,
      data: (rate) => rate == null
          ? 'No rate set for this item'
          : '\u20B9${rate.toDouble().toStringAsFixed(2)} / CFT',
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$perPiece CFT per piece',
            key: const Key('build_cft_per_piece'),
            style: theme.textTheme.textStyle,
          ),
          if (perBunch != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '$perBunch CFT per bunch',
                key: const Key('build_cft_per_bunch'),
                style: theme.textTheme.tabLabelTextStyle,
              ),
            ),
          if (rateText != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                rateText,
                key: const Key('build_rate_per_cft'),
                style: theme.textTheme.tabLabelTextStyle,
              ),
            ),
        ],
      ),
    );
  }
}

/// The list of staged target-CFT requests with a remove control per line.
class _StagedTargetList extends StatelessWidget {
  const _StagedTargetList({required this.targets, required this.onRemove});

  final List<StagedTargetRequest> targets;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (targets.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = CupertinoTheme.of(context);
    return Column(
      key: const Key('staged_targets'),
      children: [
        for (var i = 0; i < targets.length; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    targets[i].summaryLabel,
                    key: Key('staged_target_$i'),
                    style: theme.textTheme.textStyle,
                  ),
                ),
                SizedBox(
                  width: kBuildMinTouchTarget,
                  height: kBuildMinTouchTarget,
                  child: CupertinoButton(
                    key: Key('remove_target_$i'),
                    padding: EdgeInsets.zero,
                    onPressed: () => onRemove(i),
                    child: const Icon(
                      CupertinoIcons.minus_circled,
                      semanticLabel: 'Remove line',
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.canContinue,
    required this.onSaveForLater,
    required this.onContinue,
  });

  final bool canContinue;
  final VoidCallback onSaveForLater;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              key: const Key('build_save_for_later'),
              onPressed: onSaveForLater,
              child: const Text('Save for later'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoButton.filled(
              key: const Key('build_continue'),
              onPressed: canContinue ? onContinue : null,
              child: const Text('Review'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Text(
          text,
          style: CupertinoTheme.of(context)
              .textTheme
              .navTitleTextStyle
              .copyWith(fontSize: 16),
        ),
      );
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: kBuildMinTouchTarget + 8,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (final child in children) ...[
              child,
              const SizedBox(width: 8),
            ],
          ],
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({
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
      minimumSize: const Size(kBuildMinTouchTarget, kBuildMinTouchTarget),
      onPressed: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: kBuildMinTouchTarget),
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

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: CupertinoActivityIndicator(),
      );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(message),
      );
}
