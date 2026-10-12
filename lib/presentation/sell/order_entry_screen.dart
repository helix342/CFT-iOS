/// The Sell-tab order-entry screen: the four structured request types
/// (task 8.2).
///
/// This is the order-request entry surface from design.md -> Screen Flows ->
/// Sell tab -> "Order request entry (Requirement 7)". Entry is **structured
/// only** — there is no natural-language or AI interpretation (Requirement
/// 7.1). The owner picks ONE of exactly FOUR request shapes with a segmented
/// control and fills the fields that shape constrains:
///
///   1. **Exact quantity** (Requirement 7.2) — a fully pinned SKU: variety +
///      cross-section + length + a whole-unit quantity (bunches for a reaper,
///      pieces for a plank). Produces an [ExactQtyRequest].
///   2. **Target CFT · exact length** (Requirement 7.3) — variety +
///      cross-section + length + a target CFT. Produces a
///      [TargetCftFixedLengthRequest].
///   3. **Target CFT · cross-section** (Requirement 7.4) — variety +
///      cross-section + a target CFT, lengths flexible. Produces a
///      [TargetCftFlexCrossSectionRequest].
///   4. **Target CFT · category** (Requirement 7.5) — variety + category
///      (reaper or plank) + a target CFT, cross-section and lengths flexible.
///      Produces a [TargetCftFlexCategoryRequest].
///
/// Target-CFT requests are always **meet-or-exceed** (round up); there is no
/// at-most/closest option (Requirement 7.6, CD-3), so the forms expose only a
/// target value with the fixed "meet or exceed" direction labelled, never a
/// direction selector.
///
/// A completed form is appended to the draft through
/// `draftOrderRequestsProvider`; the staged requests are listed below the form
/// so the owner can see what the order contains and remove a line. Running the
/// allocation heuristic and the picking-list review are later tasks (9.x); this
/// screen's job is to produce VALID structured [OrderRequest] value objects.
///
/// Accessibility (Requirement 17.3, 17.6): every tappable control is at least
/// 44 × 44 pt, and quantities/CFT are shown with explicit unit labels
/// ("bunches", "pcs", "CFT") — never a bare number.
///
/// Architecture rule (design.md): this widget is presentation-only. Catalog
/// reads and the draft store live behind the providers in `sell_providers.dart`;
/// request validation lives in the domain [OrderRequest] constructors.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/order_request.dart';
import 'package:wood_cft/presentation/sell/sell_providers.dart';

/// The minimum accessible touch-target size in logical pixels (Req 17.3).
const double kMinTouchTarget = 44;

/// The inclusive length choices offered for a pinned-length request (2–9 ft).
const List<int> kSellLengthsFt = [2, 3, 4, 5, 6, 7, 8, 9];

/// The four structured request shapes, in the order shown on the segmented
/// control (mirrors [OrderRequestKind]).
enum _RequestFormKind {
  exactQty,
  targetCftFixedLength,
  targetCftFlexCrossSection,
  targetCftFlexCategory;

  /// The short segmented-control label for this shape.
  String get shortLabel => switch (this) {
        _RequestFormKind.exactQty => 'Exact qty',
        _RequestFormKind.targetCftFixedLength => 'CFT · length',
        _RequestFormKind.targetCftFlexCrossSection => 'CFT · section',
        _RequestFormKind.targetCftFlexCategory => 'CFT · category',
      };

  /// The one-line description of what this shape constrains.
  String get description => switch (this) {
        _RequestFormKind.exactQty =>
          'Exact quantity of one specific size (Req 7.2).',
        _RequestFormKind.targetCftFixedLength =>
          'Target CFT at one exact length, meet or exceed (Req 7.3, 7.6).',
        _RequestFormKind.targetCftFlexCrossSection =>
          'Target CFT for a cross-section, flexible lengths (Req 7.4).',
        _RequestFormKind.targetCftFlexCategory =>
          'Target CFT within a category, flexible lengths (Req 7.5).',
      };
}

/// The Sell-tab order-entry screen.
class OrderEntryScreen extends ConsumerStatefulWidget {
  /// Creates the order-entry screen.
  const OrderEntryScreen({super.key});

  @override
  ConsumerState<OrderEntryScreen> createState() => _OrderEntryScreenState();
}

class _OrderEntryScreenState extends ConsumerState<OrderEntryScreen> {
  _RequestFormKind _kind = _RequestFormKind.exactQty;

  // Shared selection state across the forms.
  int? _varietyId;
  CrossSection? _crossSection;
  WoodCategory? _category;
  int? _lengthFt;

  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _targetCftController = TextEditingController();

  /// The most recent inline feedback shown under the add button.
  String? _feedback;

  @override
  void dispose() {
    _quantityController.dispose();
    _targetCftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final varietiesAsync = ref.watch(sellVarietiesProvider);
    final crossSectionsAsync = ref.watch(sellCrossSectionsProvider);
    final staged = ref.watch(draftOrderRequestsProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('New order'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            const _SectionLabel('Request type'),
            _RequestTypePicker(
              kind: _kind,
              onChanged: (k) => setState(() {
                _kind = k;
                _feedback = null;
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                _kind.description,
                key: const Key('request_type_description'),
                style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle,
              ),
            ),
            const SizedBox(height: 16),
            const _SectionLabel('Variety'),
            varietiesAsync.when(
              loading: () => const _LoadingRow(),
              error: (e, _) => _ErrorRow('Could not load varieties: $e'),
              data: (varieties) => _VarietyPicker(
                varieties: varieties,
                selectedId: _varietyId,
                onSelected: (row) => setState(() {
                  _varietyId = row.id;
                  _feedback = null;
                }),
              ),
            ),
            const SizedBox(height: 16),
            crossSectionsAsync.when(
              loading: () => const _LoadingRow(),
              error: (e, _) => _ErrorRow('Could not load cross-sections: $e'),
              data: _buildConstraintFields,
            ),
            const SizedBox(height: 24),
            _buildSubmitSection(context),
            const SizedBox(height: 24),
            const _SectionLabel('Order lines'),
            _StagedRequestList(
              requests: staged,
              onRemove: (i) => ref
                  .read(draftOrderRequestsProvider.notifier)
                  .removeAt(i),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the shape-specific constraint fields (cross-section / category /
  /// length / quantity / target CFT) for the currently selected [_kind].
  Widget _buildConstraintFields(List<CrossSection> crossSections) {
    final needsCrossSection = _kind != _RequestFormKind.targetCftFlexCategory;
    final needsCategory = _kind == _RequestFormKind.targetCftFlexCategory;
    final needsLength = _kind == _RequestFormKind.exactQty ||
        _kind == _RequestFormKind.targetCftFixedLength;
    final needsQuantity = _kind == _RequestFormKind.exactQty;
    final needsTargetCft = _kind != _RequestFormKind.exactQty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (needsCrossSection) ...[
          const _SectionLabel('Cross-section'),
          _CrossSectionPicker(
            crossSections: crossSections,
            selectedId: _crossSection?.id,
            onSelected: (cs) => setState(() {
              _crossSection = cs;
              _feedback = null;
            }),
          ),
          const SizedBox(height: 16),
        ],
        if (needsCategory) ...[
          const _SectionLabel('Category'),
          _CategoryPicker(
            selected: _category,
            onSelected: (c) => setState(() {
              _category = c;
              _feedback = null;
            }),
          ),
          const SizedBox(height: 16),
        ],
        if (needsLength) ...[
          const _SectionLabel('Length'),
          _LengthPicker(
            selected: _lengthFt,
            onSelected: (l) => setState(() {
              _lengthFt = l;
              _feedback = null;
            }),
          ),
          const SizedBox(height: 16),
        ],
        if (needsQuantity) ...[
          _SectionLabel(_quantityLabel()),
          _QuantityField(
            controller: _quantityController,
            placeholder: _quantityPlaceholder(),
            onChanged: () => setState(() => _feedback = null),
          ),
          const SizedBox(height: 16),
        ],
        if (needsTargetCft) ...[
          const _SectionLabel('Target CFT (meet or exceed)'),
          _TargetCftField(
            controller: _targetCftController,
            onChanged: () => setState(() => _feedback = null),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  String _quantityLabel() {
    final isReaper = _crossSection?.category == WoodCategory.reaper;
    return isReaper ? 'Quantity (bunches of 10)' : 'Quantity (pieces)';
  }

  String _quantityPlaceholder() {
    final isReaper = _crossSection?.category == WoodCategory.reaper;
    return isReaper ? 'bunches' : 'pieces';
  }

  Widget _buildSubmitSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CupertinoButton.filled(
            key: const Key('add_request_button'),
            onPressed: _submit,
            child: const Text('Add to order'),
          ),
          if (_feedback != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _feedback!,
                key: const Key('order_entry_feedback'),
                style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle,
              ),
            ),
        ],
      ),
    );
  }

  /// Validates the current form and, when valid, appends a structured
  /// [OrderRequest] to the draft. On any invalid input it sets inline feedback
  /// and does NOT mutate the draft.
  void _submit() {
    final varietyId = _varietyId;
    if (varietyId == null) {
      setState(() => _feedback = 'Select a variety first.');
      return;
    }

    final OrderRequest request;
    try {
      request = switch (_kind) {
        _RequestFormKind.exactQty => _buildExactQty(varietyId),
        _RequestFormKind.targetCftFixedLength =>
          _buildTargetFixedLength(varietyId),
        _RequestFormKind.targetCftFlexCrossSection =>
          _buildTargetFlexCrossSection(varietyId),
        _RequestFormKind.targetCftFlexCategory =>
          _buildTargetFlexCategory(varietyId),
      };
    } on _FormException catch (e) {
      setState(() => _feedback = e.message);
      return;
    } on RangeError catch (e) {
      setState(() => _feedback = '${e.message}');
      return;
    } on ArgumentError catch (e) {
      setState(() => _feedback = '${e.message}');
      return;
    }

    ref.read(draftOrderRequestsProvider.notifier).add(request);
    setState(() {
      _feedback = 'Added ${_kind.shortLabel} line to the order.';
      _quantityController.clear();
      _targetCftController.clear();
    });
  }

  ExactQtyRequest _buildExactQty(int varietyId) {
    final cs = _requireCrossSection();
    final lengthFt = _requireLength();
    final qty = int.tryParse(_quantityController.text.trim());
    if (qty == null || qty <= 0) {
      throw const _FormException('Enter a positive whole quantity.');
    }
    return ExactQtyRequest(
      varietyId: varietyId,
      crossSectionId: cs.id,
      lengthFt: lengthFt,
      quantityUnits: qty,
    );
  }

  TargetCftFixedLengthRequest _buildTargetFixedLength(int varietyId) {
    final cs = _requireCrossSection();
    final lengthFt = _requireLength();
    final target = _requireTargetCft();
    return TargetCftFixedLengthRequest(
      varietyId: varietyId,
      crossSectionId: cs.id,
      lengthFt: lengthFt,
      targetCft: target,
    );
  }

  TargetCftFlexCrossSectionRequest _buildTargetFlexCrossSection(int varietyId) {
    final cs = _requireCrossSection();
    final target = _requireTargetCft();
    return TargetCftFlexCrossSectionRequest(
      varietyId: varietyId,
      crossSectionId: cs.id,
      targetCft: target,
    );
  }

  TargetCftFlexCategoryRequest _buildTargetFlexCategory(int varietyId) {
    final category = _category;
    if (category == null) {
      throw const _FormException('Select a category.');
    }
    final target = _requireTargetCft();
    return TargetCftFlexCategoryRequest(
      varietyId: varietyId,
      category: category,
      targetCft: target,
    );
  }

  CrossSection _requireCrossSection() {
    final cs = _crossSection;
    if (cs == null) throw const _FormException('Select a cross-section.');
    return cs;
  }

  int _requireLength() {
    final l = _lengthFt;
    if (l == null) throw const _FormException('Select a length.');
    return l;
  }

  Rational _requireTargetCft() {
    final text = _targetCftController.text.trim();
    if (text.isEmpty) {
      throw const _FormException('Enter a target CFT.');
    }
    final Rational value;
    try {
      value = Rational.parse(text);
    } on FormatException {
      throw const _FormException('Target CFT must be a number.');
    }
    if (value <= Rational.zero) {
      throw const _FormException('Target CFT must be greater than zero.');
    }
    return value;
  }
}

/// A validation failure surfaced inline on the form (never thrown out of the
/// widget).
class _FormException implements Exception {
  const _FormException(this.message);
  final String message;
}

/// The segmented control that picks one of the four request shapes.
class _RequestTypePicker extends StatelessWidget {
  const _RequestTypePicker({required this.kind, required this.onChanged});

  final _RequestFormKind kind;
  final ValueChanged<_RequestFormKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<_RequestFormKind>(
          key: const Key('request_type_segments'),
          groupValue: kind,
          onValueChanged: (k) {
            if (k != null) onChanged(k);
          },
          children: {
            for (final k in _RequestFormKind.values)
              k: Padding(
                key: Key('request_type_${k.name}'),
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
            label: '${cs.inchLabel} · $kind',
            selected: cs.id == selectedId,
            onTap: () => onSelected(cs),
          );
        },
      ),
    );
  }
}

/// A reaper/plank category picker (flexible-category request).
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.selected, required this.onSelected});

  final WoodCategory? selected;
  final ValueChanged<WoodCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kMinTouchTarget + 8,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final c in WoodCategory.values) ...[
            _ChoiceChip(
              key: Key('category_choice_${c.name}'),
              label: c == WoodCategory.reaper ? 'Reaper' : 'Plank',
              selected: c == selected,
              onTap: () => onSelected(c),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// A 2–9 ft length picker (pinned-length requests).
class _LengthPicker extends StatelessWidget {
  const _LengthPicker({required this.selected, required this.onSelected});

  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kMinTouchTarget + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: kSellLengthsFt.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final l = kSellLengthsFt[i];
          return _ChoiceChip(
            key: Key('length_choice_$l'),
            label: '$l ft',
            selected: l == selected,
            onTap: () => onSelected(l),
          );
        },
      ),
    );
  }
}

/// A whole-number quantity field (bunches or pieces).
class _QuantityField extends StatelessWidget {
  const _QuantityField({
    required this.controller,
    required this.placeholder,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String placeholder;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CupertinoTextField(
        key: const Key('quantity_field'),
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: false,
          signed: false,
        ),
        placeholder: placeholder,
        onChanged: (_) => onChanged(),
      ),
    );
  }
}

/// A decimal target-CFT field parsed into an exact rational on submit.
class _TargetCftField extends StatelessWidget {
  const _TargetCftField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CupertinoTextField(
        key: const Key('target_cft_field'),
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: false,
        ),
        placeholder: 'CFT',
        suffix: const Padding(
          padding: EdgeInsets.only(right: 8),
          child: Text('CFT'),
        ),
        onChanged: (_) => onChanged(),
      ),
    );
  }
}

/// The list of staged order requests with a remove control per line.
class _StagedRequestList extends StatelessWidget {
  const _StagedRequestList({required this.requests, required this.onRemove});

  final List<OrderRequest> requests;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'No lines yet. Build the order above.',
          key: Key('staged_requests_empty'),
        ),
      );
    }
    return Column(
      key: const Key('staged_requests'),
      children: [
        for (var i = 0; i < requests.length; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _describe(requests[i]),
                    key: Key('staged_request_$i'),
                    style: CupertinoTheme.of(context).textTheme.textStyle,
                  ),
                ),
                SizedBox(
                  width: kMinTouchTarget,
                  height: kMinTouchTarget,
                  child: CupertinoButton(
                    key: Key('remove_request_$i'),
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

  /// A human-readable one-line summary of a staged request (unit-labelled).
  String _describe(OrderRequest r) => switch (r) {
        ExactQtyRequest() =>
          'Exact · variety ${r.varietyId} · section ${r.crossSectionId} · '
              '${r.lengthFt} ft · ${r.quantityUnits} units',
        TargetCftFixedLengthRequest() =>
          'Target ≥ ${r.targetCft.toDouble().toStringAsFixed(4)} CFT · '
              'variety ${r.varietyId} · section ${r.crossSectionId} · '
              '${r.lengthFt} ft',
        TargetCftFlexCrossSectionRequest() =>
          'Target ≥ ${r.targetCft.toDouble().toStringAsFixed(4)} CFT · '
              'variety ${r.varietyId} · section ${r.crossSectionId} · '
              'flexible lengths',
        TargetCftFlexCategoryRequest() =>
          'Target ≥ ${r.targetCft.toDouble().toStringAsFixed(4)} CFT · '
              'variety ${r.varietyId} · ${r.category.name} · flexible',
      };
}

/// A selectable chip whose tappable area is at least 44×44 (Req 17.3).
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
