/// The first-run setup screen (task 15.2).
///
/// Shown once on a fresh install, before the bottom tabs, to request the
/// MINIMUM configuration needed to begin (design.md -> Screen Flows, First-run
/// setup; Requirements 1.1, 1.2, 1.12, 17.12, 18.2, 18.5):
///
///   * a required **business name** — the one field needed to issue a bill
///     (never pre-filled with an assumed value — Requirement 18.2);
///   * optional **invoice prefix** and **GSTIN** the owner may fill now or
///     later in Settings (GSTIN is never fabricated — Requirement 18.5).
///
/// Completing the flow seeds the shipped catalog with ZERO stock and NO prices
/// (via [FirstRunController]) and persists the entered profile. It explicitly
/// states that no stock or prices are created, so the owner knows the app
/// starts empty and honest. The timezone defaults to Asia/Kolkata without
/// asking (Requirement 17.12).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wood_cft/domain/business_settings.dart';
import 'package:wood_cft/presentation/settings/first_run_providers.dart';

/// The first-run setup form, wired via Riverpod to [firstRunControllerProvider].
class FirstRunScreen extends ConsumerStatefulWidget {
  /// Creates the first-run screen.
  const FirstRunScreen({super.key});

  @override
  ConsumerState<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends ConsumerState<FirstRunScreen> {
  final _nameController = TextEditingController();
  final _invoicePrefixController = TextEditingController();
  final _gstinController = TextEditingController();

  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _invoicePrefixController.dispose();
    _gstinController.dispose();
    super.dispose();
  }

  Future<void> _begin() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a business name to begin.');
      return;
    }
    setState(() => _error = null);

    final gstin = _gstinController.text.trim();
    final profile = BusinessProfile(
      name: name,
      invoicePrefix: _invoicePrefixController.text.trim(),
      // Absent GSTIN stays null — never fabricate one (Requirement 18.5).
      gstin: gstin.isEmpty ? null : gstin,
    );

    await ref
        .read(firstRunControllerProvider.notifier)
        .complete(profile: profile);
  }

  @override
  Widget build(BuildContext context) {
    final setupState = ref.watch(firstRunControllerProvider);
    final theme = CupertinoTheme.of(context);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Welcome'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Set up your shop to begin. We start with an empty catalog — '
                'no stock and no prices are created for you. You can receive '
                'stock and set prices afterwards.',
                key: const Key('first_run_empty_note'),
                style: theme.textTheme.tabLabelTextStyle,
              ),
            ),
            const SizedBox(height: 16),
            _Field(
              label: 'Business name',
              controller: _nameController,
              placeholder: 'Your shop name',
              fieldKey: const Key('first_run_name_field'),
            ),
            _Field(
              label: 'Invoice prefix (optional)',
              controller: _invoicePrefixController,
              placeholder: 'e.g. INV-',
              fieldKey: const Key('first_run_invoice_prefix_field'),
            ),
            _Field(
              label: 'GSTIN (optional)',
              controller: _gstinController,
              placeholder: 'Leave blank if not registered',
              fieldKey: const Key('first_run_gstin_field'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  _error!,
                  key: const Key('first_run_error'),
                  style: const TextStyle(
                    color: CupertinoColors.systemRed,
                    fontSize: 13,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoButton.filled(
                key: const Key('first_run_begin_button'),
                onPressed: setupState.isLoading ? null : _begin,
                child: setupState.isLoading
                    ? const CupertinoActivityIndicator()
                    : const Text('Begin'),
              ),
            ),
            if (setupState.hasError)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  'Setup failed: ${setupState.error}',
                  key: const Key('first_run_setup_error'),
                  style: const TextStyle(
                    color: CupertinoColors.systemRed,
                    fontSize: 13,
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// A labelled Cupertino text field used by the first-run form.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.placeholder,
    required this.fieldKey,
  });

  final String label;
  final TextEditingController controller;
  final String placeholder;
  final Key fieldKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: CupertinoTheme.of(context).textTheme.textStyle),
          const SizedBox(height: 6),
          CupertinoTextField(
            key: fieldKey,
            controller: controller,
            placeholder: placeholder,
          ),
        ],
      ),
    );
  }
}
