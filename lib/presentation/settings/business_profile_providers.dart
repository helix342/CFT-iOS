/// Riverpod wiring for the business-profile settings surface (task 13.1).
///
/// This exposes the drift [AppDatabase], the [BusinessSettingsRepository], and
/// an [AsyncNotifier] that loads and persists the [BusinessProfile] singleton
/// for the Settings -> "Business profile" screen (design.md -> Screen Flows,
/// Settings; Requirement 18).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/business_settings_repository.dart';
import 'package:wood_cft/domain/business_settings.dart';

/// Provides the on-device drift database.
///
/// Overridden in tests with an in-memory database (see
/// [openInMemoryDatabase]). The real app uses the default on-device file.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Provides the business-profile repository bound to [appDatabaseProvider].
final businessSettingsRepositoryProvider =
    Provider<BusinessSettingsRepository>((ref) {
  return BusinessSettingsRepository(ref.watch(appDatabaseProvider));
});

/// Loads and persists the business profile for the settings form.
///
/// [build] reads the current profile from storage; a fresh install resolves to
/// [BusinessProfile.empty] (no assumed name — Requirement 18.2; no fabricated
/// registration — Requirement 18.5). [save] writes an edited profile and
/// refreshes the in-memory state.
class BusinessProfileNotifier extends AsyncNotifier<BusinessProfile> {
  @override
  Future<BusinessProfile> build() {
    return ref.watch(businessSettingsRepositoryProvider).load();
  }

  /// Persists [profile] and updates the exposed state on success.
  Future<void> save(BusinessProfile profile) async {
    final repo = ref.read(businessSettingsRepositoryProvider);
    state = const AsyncLoading<BusinessProfile>();
    state = await AsyncValue.guard(() async {
      await repo.save(profile);
      return profile;
    });
  }
}

/// The business-profile notifier provider used by the settings screen.
final businessProfileProvider =
    AsyncNotifierProvider<BusinessProfileNotifier, BusinessProfile>(
  BusinessProfileNotifier.new,
);
