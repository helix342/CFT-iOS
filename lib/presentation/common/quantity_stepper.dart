/// A reusable +/- quantity stepper (app-ux-revamp Requirements 2, 3).
///
/// Presents a decrement button, the current whole-count value, and an
/// increment button. The value is tappable to type an exact count via a modal
/// numeric entry, so large quantities need not be reached one tap at a time
/// (Requirement 2.3, OD-5). The control clamps to `>= 0` (never negative) and
/// every tappable surface meets the 44x44 pt minimum touch target, with
/// accessible labels that include the unit word (Requirement 2.6).
///
/// It is a controlled widget: it renders `value` and reports changes via
/// `onChanged`; it holds no count state of its own. It is shared by the
/// Receiving length grid (Requirement 2) and the staged order lines
/// (Requirement 3).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// The minimum accessible touch-target size in logical pixels (Req 2.6).
const double kStepperMinTouchTarget = 44;

/// A controlled +/- stepper over a whole, non-negative [value].
class QuantityStepper extends StatelessWidget {
  /// Creates a stepper rendering [value] in units of [unitLabel].
  const QuantityStepper({
    required this.value,
    required this.onChanged,
    required this.unitLabel,
    this.minValue = 0,
    this.maxValue,
    this.enabled = true,
    super.key,
  });

  /// The current whole count shown between the -/+ buttons.
  final int value;

  /// Called with the new clamped value whenever the owner adjusts the count.
  final ValueChanged<int> onChanged;

  /// The unit word spoken/announced with the value (e.g. `bunches`, `pcs`).
  final String unitLabel;

  /// The lowest permitted value; the control never goes below it (default 0).
  final int minValue;

  /// The optional highest permitted value; `null` means unbounded above.
  final int? maxValue;

  /// Whether the control accepts input.
  final bool enabled;

  int _clamp(int next) {
    var v = next;
    if (v < minValue) v = minValue;
    final max = maxValue;
    if (max != null && v > max) v = max;
    return v;
  }

  void _emit(int next) {
    final clamped = _clamp(next);
    if (clamped != value) onChanged(clamped);
  }

  Future<void> _promptDirectEntry(BuildContext context) async {
    final controller = TextEditingController(text: '$value');
    final entered = await showCupertinoDialog<int>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Enter $unitLabel'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            key: const Key('quantity_stepper_direct_field'),
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: false,
              signed: false,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            placeholder: unitLabel,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              // Reject non-whole/negative input: only digits were allowed, so
              // a parse failure means empty -> treat as no change.
              final parsed = int.tryParse(controller.text.trim());
              Navigator.of(context).pop(parsed);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (entered != null) _emit(entered);
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final canDecrement = enabled && value > minValue;
    final max = maxValue;
    final canIncrement = enabled && (max == null || value < max);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          key: const Key('quantity_stepper_decrement'),
          icon: CupertinoIcons.minus,
          semanticLabel: 'Decrease $unitLabel',
          onPressed: canDecrement ? () => _emit(value - 1) : null,
        ),
        GestureDetector(
          onTap: enabled ? () => _promptDirectEntry(context) : null,
          behavior: HitTestBehavior.opaque,
          child: Semantics(
            label: '$value $unitLabel',
            button: true,
            child: Container(
              key: const Key('quantity_stepper_value'),
              constraints: const BoxConstraints(
                minWidth: kStepperMinTouchTarget,
                minHeight: kStepperMinTouchTarget,
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '$value',
                style: theme.textTheme.textStyle,
              ),
            ),
          ),
        ),
        _StepperButton(
          key: const Key('quantity_stepper_increment'),
          icon: CupertinoIcons.plus,
          semanticLabel: 'Increase $unitLabel',
          onPressed: canIncrement ? () => _emit(value + 1) : null,
        ),
      ],
    );
  }
}

/// A 44x44 icon button used for the -/+ affordances.
class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kStepperMinTouchTarget,
      height: kStepperMinTouchTarget,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: Icon(icon, semanticLabel: semanticLabel),
      ),
    );
  }
}
