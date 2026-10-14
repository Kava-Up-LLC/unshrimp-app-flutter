import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_well_app/core/cache/cache_status.dart';
import 'package:move_well_app/features/auth/repositories/token_storage.dart';
import 'package:move_well_app/features/settings/repositories/settings_repository.dart';
import 'package:move_well_app/features/settings/view_models/settings_view_model.dart';

import '../auth/fakes.dart';
import 'fakes.dart';

ProviderContainer _container(FakeSettingsRepository repo) {
  final container = ProviderContainer(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(repo),
      tokenStorageProvider.overrideWithValue(FakeTokenStorage('t')),
    ],
  );
  addTearDown(container.dispose);
  container.listen(settingsViewModelProvider, (_, _) {});
  return container;
}

void main() {
  test('offline, Settings loads the cached row and flags offline', () async {
    final asOf = DateTime(2024, 1, 1, 10, 42);
    final repo = FakeSettingsRepository(offline: true, asOf: asOf);
    final container = _container(repo);

    final state = await container.read(settingsViewModelProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(state.settings, same(testSettings));
    expect(container.read(cacheStatusProvider).offline, isTrue);
    expect(container.read(cacheStatusProvider).asOf, asOf);
  });

  test('Settings reads once on load and does not revalidate in the background', () async {
    final repo = FakeSettingsRepository();
    final container = _container(repo);

    await container.read(settingsViewModelProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(repo.fetchCalls, 1);
  });
}
