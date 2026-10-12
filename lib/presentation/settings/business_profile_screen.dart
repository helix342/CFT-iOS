/// The Settings -> "Business profile" screen (task 13.1).
///
/// A Cupertino editable form over the [BusinessProfile] singleton
/// (design.md -> Screen Flows, Settings; Requirement 18). The owner configures
/// the business name, address, phone, optional GSTIN, and invoice prefix.
///
/// Honesty rules surfaced to the UI (Requirement 18): fields start blank on a
/// fresh install — the name is never pre-filled with an assumed value such as
/// "Zenith Systems" (Requirement 18.2) and the GSTIN is never fabricated
/// (Requirement 18.5). The invoice prefix is captured here so invoice
/// numbering (task 11) can consume it later.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wood_cft/domain/business_settings.dart';
import 'package:wood_cft/presentation/settings/business_profile_providers.dart';

/// Editable business-profile form, wired via Riverpod to the singleton store.
class BusinessProfileScreen extends ConsumerStatefulWidget {
  /// Creates the business-profile screen.
  const BusinessProfileScreen({super.key});

  @override
  ConsumerState<BusinessProfileScreen> createState() =>
      _BusinessProfileScreenState();
}

class _BusinessProfileScreenState
    extends ConsumerState<BusinessProfileScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _gstinController = TextEditingController();
  final _invoicePrefixController = TextEditingController();

  /// Whether the controllers have been seeded from the first loaded profile.
  bool _seeded = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _gstinController.dispose();
    _invoicePrefixController.dispose();
    super.dispose();
  }

  void _seedControllers(BusinessProfile profile) {
    _nameController.text = profile.name;
    _addressController.text = profile.address;
    _phoneController.text = profile.phone;
    _gstinController.text = profile.gstin ?? '';
    _invoicePrefixController.text = profile.invoicePrefix;
    _seeded = true;
  }

  Future<void> _save() async {
    final gstinText = _gstinController.text.trim();
    final edited = BusinessProfile(
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      // Keep logo unchanged: logo editing is out of scope for this screen.
      logo: ref.read(businessProfileProvider).value?.logo,
      // Absent GSTIN stays null; never fabricate a value (Requirement 18.5).
      gstin: gstinText.isEmpty ? null : gstinText,
      invoicePrefix: _invoicePrefixController.text.trim(),
    );
    await ref.read(businessProfileProvider.notifier).save(edited);
  }

  @override
  Widget build(BuildContext context) {
    final asyncProfile = ref.watch(businessProfileProvider);

    // Seed the text fields once, from the first successfully loaded profile.
    ref.listen<AsyncValue<BusinessProfile>>(businessProfileProvider, (
      previous,
      next,
    ) {
      final profile = next.value;
      if (!_seeded && profile != null) {
        setState(() => _seedControllers(profile));
      }
    });
    if (!_seeded) {
      final profile = asyncProfile.value;
      if (profile != null) _seedControllers(profile);
    }

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Business profile'),
      ),
      child: SafeArea(
        child: asyncProfile.when(
          loading: () =>
              const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Could not load business profile: $error'),
            ),
          ),
          data: (_) => _buildForm(context),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 16),
        _FormField(
          label: 'Business name',
          controller: _nameController,
          placeholder: 'Your shop name',
          key: const Key('business_name_field'),
        ),
        _FormField(
          label: 'Address',
          controller: _addressController,
          placeholder: 'Shop address',
          maxLines: 3,
          key: const Key('business_address_field'),
        ),
        _FormField(
          label: 'Phone',
          controller: _phoneController,
          placeholder: 'Contact phone',
          keyboardType: TextInputType.phone,
          key: const Key('business_phone_field'),
        ),
        _FormField(
          label: 'GSTIN (optional)',
          controller: _gstinController,
          placeholder: 'Leave blank if not registered',
          key: const Key('business_gstin_field'),
        ),
        _FormField(
          label: 'Invoice prefix',
          controller: _invoicePrefixController,
          placeholder: 'e.g. INV-',
          key: const Key('business_invoice_prefix_field'),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CupertinoButton.filled(
            key: const Key('business_profile_save_button'),
            onPressed: _save,
            child: const Text('Save'),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// A labelled Cupertino text field used by the business-profile form.
class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.controller,
    required this.placeholder,
    this.keyboardType,
    this.maxLines = 1,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String placeholder;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: CupertinoTheme.of(context).textTheme.textStyle,
          ),
          const SizedBox(height: 6),
          CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            keyboardType: keyboardType,
            maxLines: maxLines,
          ),
        ],
      ),
    );
  }
}
