import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_well_app/features/auth/models/auth_exception.dart';
import 'package:move_well_app/features/auth/repositories/token_storage.dart';
import 'package:move_well_app/features/home/repositories/home_repository.dart';
import 'package:move_well_app/features/home/view_models/home_view_model.dart';
import 'package:move_well_app/features/notifications/repositories/delivery_log.dart';
import 'package:move_well_app/features/reminders/repositories/reminder_preferences.dart';
import 'package:move_well_app/features/reminders/services/reminder_scheduler.dart';

import '../../support/in_memory_prefs.dart';
import '../auth/fakes.dart';
import '../notifications/fakes.dart';
import '../reminders/fakes.dart';
import 'fakes.dart';

ProviderContainer _container(
  FakeHomeRepository repo,
  FakeTokenStorage store, [
  FakeReminderScheduler? scheduler,
]) {
  final container = ProviderContainer(
    overrides: [
      homeRepositoryProvider.overrideWithValue(repo),
      tokenStorageProvider.overrideWithValue(store),
      reminderSchedulerProvider.overrideWithValue(
        scheduler ?? FakeReminderScheduler(),
      ),
      deliveryLogProvider.overrideWithValue(FakeDeliveryLog()),
      reminderPreferencesProvider.overrideWithValue(FakeReminderPreferences()),
    ],
  );
  addTearDown(container.dispose);
  // Keeps the autoDispose provider alive while the test awaits it.
  container.listen(homeViewModelProvider, (_, _) {});
  return container;
}

void main() {
  setUp(useInMemoryPrefs);

  test('loads the stats for the stored token', () async {
    final repo = FakeHomeRepository();
    final container = _container(repo, FakeTokenStorage('t'));

    final stats = await container.read(homeViewModelProvider.future);

    expect(stats.currentStreak, 4);
    expect(stats.roastLevel, 3);
    expect(stats.breaksToday, 2);
    expect(repo.calls, 1);
  });

  test('no stored token fails with INVALID_TOKEN and never calls the '
      'backend', () async {
    final repo = FakeHomeRepository();
    final container = _container(repo, FakeTokenStorage());

    while (container.read(homeViewModelProvider).isLoading) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(
      container.read(homeViewModelProvider).error,
      isA<AuthException>().having((e) => e.code, 'code', 'INVALID_TOKEN'),
    );
    expect(repo.calls, 0);
  });

  test('logOut cancels the reminders and clears the stored token', () async {
    final store = FakeTokenStorage('t');
    final scheduler = FakeReminderScheduler();
    final container = _container(FakeHomeRepository(), store, scheduler);
    await container.read(homeViewModelProvider.future);

    await container.read(homeViewModelProvider.notifier).logOut();

    expect(store.token, isNull);
    expect(scheduler.cancelCalls, 1);
  });
}
