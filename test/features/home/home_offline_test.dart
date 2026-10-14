import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_well_app/core/cache/cache_status.dart';
import 'package:move_well_app/features/auth/repositories/token_storage.dart';
import 'package:move_well_app/features/home/models/user_stats.dart';
import 'package:move_well_app/features/home/repositories/home_repository.dart';
import 'package:move_well_app/features/home/view_models/home_view_model.dart';
import 'package:move_well_app/features/notifications/repositories/delivery_log.dart';
import 'package:move_well_app/features/reminders/repositories/reminder_preferences.dart';
import 'package:move_well_app/features/reminders/services/reminder_scheduler.dart';

import '../auth/fakes.dart';
import '../notifications/fakes.dart';
import '../reminders/fakes.dart';
import 'fakes.dart';

ProviderContainer _container(FakeHomeRepository repo) {
  final container = ProviderContainer(
    overrides: [
      homeRepositoryProvider.overrideWithValue(repo),
      tokenStorageProvider.overrideWithValue(FakeTokenStorage('t')),
      reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
      deliveryLogProvider.overrideWithValue(FakeDeliveryLog()),
      reminderPreferencesProvider.overrideWithValue(FakeReminderPreferences()),
    ],
  );
  addTearDown(container.dispose);
  container.listen(homeViewModelProvider, (_, _) {});
  return container;
}

const _cached = UserStats(
  userId: 3,
  name: 'Grace Hopper',
  archetype: null,
  currentStreak: 9,
  breaksToday: 1,
  ignoredCount: 0,
  roastLevel: 0,
  roastPending: false,
);

void main() {
  test('a transport failure keeps Home on cached stats and flags offline', () async {
    final asOf = DateTime(2024, 1, 1, 10, 42);
    final repo = FakeHomeRepository(stats: _cached, offline: true, asOf: asOf);
    final container = _container(repo);

    final stats = await container.read(homeViewModelProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(stats.currentStreak, 9);
    final status = container.read(cacheStatusProvider);
    expect(status.offline, isTrue);
    expect(status.asOf, asOf);
  });

  test('an online load clears the offline flag', () async {
    final repo = FakeHomeRepository();
    final container = _container(repo);

    await container.read(homeViewModelProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(cacheStatusProvider).offline, isFalse);
  });

  test('paints the cached stats first, then the live stats', () async {
    final repo = FakeHomeRepository(stats: testStats, cached: _cached);
    final container = _container(repo);

    final first = await container.read(homeViewModelProvider.future);
    expect(first.currentStreak, 9); // cached, painted instantly

    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(homeViewModelProvider).requireValue.currentStreak,
      4, // live, after revalidation
    );
  });
}
