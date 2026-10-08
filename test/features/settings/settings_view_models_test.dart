import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_well_app/features/auth/models/auth_exception.dart';
import 'package:move_well_app/features/auth/repositories/token_storage.dart';
import 'package:move_well_app/features/home/models/user_stats.dart';
import 'package:move_well_app/features/home/repositories/home_repository.dart';
import 'package:move_well_app/features/home/view_models/home_view_model.dart';
import 'package:move_well_app/features/reconcile/models/reconcile_status.dart';
import 'package:move_well_app/features/reminders/services/reminder_scheduler.dart';
import 'package:move_well_app/features/settings/models/pause_option.dart';
import 'package:move_well_app/features/settings/models/user_settings.dart';
import 'package:move_well_app/features/settings/repositories/settings_repository.dart';
import 'package:move_well_app/features/settings/view_models/change_password_view_model.dart';
import 'package:move_well_app/features/settings/view_models/settings_view_model.dart';

import '../auth/fakes.dart';
import '../home/fakes.dart';
import '../reminders/fakes.dart';
import 'fakes.dart';

ProviderContainer _container(
  FakeSettingsRepository repo, {
  FakeTokenStorage? store,
  FakeReminderScheduler? scheduler,
  FakeHomeRepository? home,
}) {
  final container = ProviderContainer(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(repo),
      tokenStorageProvider.overrideWithValue(store ?? FakeTokenStorage('t')),
      reminderSchedulerProvider.overrideWithValue(
        scheduler ?? FakeReminderScheduler(),
      ),
      homeRepositoryProvider.overrideWithValue(home ?? FakeHomeRepository()),
    ],
  );
  addTearDown(container.dispose);
  // Keeps the autoDispose providers alive while the test drives them.
  container.listen(settingsViewModelProvider, (_, _) {});
  container.listen(changePasswordViewModelProvider, (_, _) {});
  return container;
}

void main() {
  group('SettingsViewModel', () {
    test('loads the user row', () async {
      final c = _container(FakeSettingsRepository());

      final state = await c.read(settingsViewModelProvider.future);

      expect(state.settings, same(testSettings));
      expect(state.isSaving, isFalse);
    });

    test('a failed load surfaces the backend error', () async {
      final c = _container(
        FakeSettingsRepository(
          fetchError: const AuthException(
            code: 'NO_SETTINGS',
            message: 'Finish onboarding to set up your reminders.',
          ),
        ),
      );

      await expectLater(
        c.read(settingsViewModelProvider.future),
        throwsA(isA<AuthException>()),
      );
      expect(
        (c.read(settingsViewModelProvider).error! as AuthException).code,
        'NO_SETTINGS',
      );
    });

    test(
      'quiet mode sends only that field and shows the returned row',
      () async {
        final repo = FakeSettingsRepository();
        final c = _container(repo);
        await c.read(settingsViewModelProvider.future);

        await c.read(settingsViewModelProvider.notifier).quietModeChanged(true);

        expect(repo.updates, [
          {'quiet_mode': true},
        ]);
        expect(
          c.read(settingsViewModelProvider).requireValue.settings.quietMode,
          isTrue,
        );
      },
    );

    test('active hours are sent as HH:mm', () async {
      final repo = FakeSettingsRepository();
      final c = _container(repo);
      await c.read(settingsViewModelProvider.future);

      await c
          .read(settingsViewModelProvider.notifier)
          .activeHoursChanged(
            startHour: 8,
            startMinute: 5,
            endHour: 17,
            endMinute: 30,
          );

      expect(repo.updates.single, {
        'active_start': '08:05',
        'active_end': '17:30',
      });
    });

    test('pause sends a UTC time that far ahead; resume clears it', () async {
      final repo = FakeSettingsRepository();
      final c = _container(repo);
      await c.read(settingsViewModelProvider.future);
      final vm = c.read(settingsViewModelProvider.notifier);

      final before = DateTime.now().add(PauseOption.threeDays.duration);
      await vm.pause(PauseOption.threeDays);
      final after = DateTime.now().add(PauseOption.threeDays.duration);
      await vm.resume();

      final sent = repo.updates.first['paused_until']! as String;
      expect(sent, endsWith('Z'));
      final until = DateTime.parse(sent);
      expect(until.isBefore(before), isFalse);
      expect(until.isAfter(after), isFalse);
      expect(repo.updates.last, {'paused_until': null});
    });

    test('a failed update keeps the row and shows the error', () async {
      final repo = FakeSettingsRepository(
        error: const AuthException(
          code: 'INVALID_SETTINGS',
          message: 'Your active hours must end after they start.',
        ),
      );
      final c = _container(repo);
      await c.read(settingsViewModelProvider.future);

      await c.read(settingsViewModelProvider.notifier).dailyGoalChanged(4);

      final state = c.read(settingsViewModelProvider).requireValue;
      expect(state.settings, same(testSettings));
      expect(state.isSaving, isFalse);
      expect(state.error?.code, 'INVALID_SETTINGS');
    });

    test('log out cancels the reminders and clears the token', () async {
      final store = FakeTokenStorage('t');
      final scheduler = FakeReminderScheduler();
      final c = _container(
        FakeSettingsRepository(),
        store: store,
        scheduler: scheduler,
      );
      await c.read(settingsViewModelProvider.future);

      await c.read(settingsViewModelProvider.notifier).logOut();

      expect(store.token, isNull);
      expect(scheduler.cancelCalls, 1);
    });

    test('a saved change reschedules from the returned row', () async {
      final scheduler = FakeReminderScheduler();
      final c = _container(FakeSettingsRepository(), scheduler: scheduler);
      await c.read(settingsViewModelProvider.future);

      await c.read(settingsViewModelProvider.notifier).quietModeChanged(true);

      expect(scheduler.rescheduled.single.quietMode, isTrue);
    });

    test('a failed change does not reschedule', () async {
      final scheduler = FakeReminderScheduler();
      final c = _container(
        FakeSettingsRepository(
          error: const AuthException(code: 'NETWORK', message: 'offline'),
        ),
        scheduler: scheduler,
      );
      await c.read(settingsViewModelProvider.future);

      await c.read(settingsViewModelProvider.notifier).dailyGoalChanged(4);

      expect(scheduler.rescheduled, isEmpty);
    });

    test('the debug reminder does not touch the schedule', () async {
      final scheduler = FakeReminderScheduler();
      final c = _container(FakeSettingsRepository(), scheduler: scheduler);
      await c.read(settingsViewModelProvider.future);

      await c.read(settingsViewModelProvider.notifier).fireTestReminder();

      expect(scheduler.testCalls, 1);
      expect(scheduler.rescheduled, isEmpty);
      expect(scheduler.cancelCalls, 0);
    });

    test('registerIgnoreDebug reports one ignore with the tz offset '
        'and pushes the row into Home', () async {
      const afterIgnore = UserStats(
        userId: 3,
        name: 'Grace Hopper',
        archetype: null,
        currentStreak: 4,
        breaksToday: 2,
        ignoredCount: 1,
        roastLevel: 1,
        roastPending: false,
      );
      final home = FakeHomeRepository(afterIgnore: afterIgnore);
      final c = _container(FakeSettingsRepository(), home: home);
      await c.read(settingsViewModelProvider.future);
      // Let Home settle before the ignore applies its row.
      final homeSub = c.listen(homeViewModelProvider, (_, _) {});
      await c.read(homeViewModelProvider.future);

      final outcome = await c
          .read(settingsViewModelProvider.notifier)
          .registerIgnoreDebug();

      expect(home.ignoreCalls, 1);
      expect(home.lastIgnoreCount, 1);
      expect(home.lastTzOffsetMin, DateTime.now().timeZoneOffset.inMinutes);
      expect(outcome.status, ReconcileStatus.counted);
      expect(outcome.ignored, 1);
      expect(outcome.batteryPercent, 80); // roast 1 -> (5-1)*20
      expect(c.read(homeViewModelProvider).value, same(afterIgnore));
      homeSub.close();
    });

    test('tone row sends the tone and refreshes the shown settings', () async {
      final repo = FakeSettingsRepository();
      final c = _container(repo);
      await c.read(settingsViewModelProvider.future);

      await c.read(settingsViewModelProvider.notifier).toneChanged('no_mercy');

      expect(repo.updates.single, {'tone': 'no_mercy'});
      expect(c.read(settingsViewModelProvider).value!.settings.tone, 'no_mercy');
    });

    test('isPausedAt ignores a pause that already ended', () {
      final now = DateTime.utc(2026, 9, 22, 12);
      UserSettings pausedUntil(DateTime? until) => UserSettings(
        activeStart: '09:00',
        activeEnd: '18:00',
        reminderIntervalMin: 60,
        graceWindowMin: 60,
        dailyGoal: 5,
        tone: 'direct',
        painZone: 'neck',
        quietMode: false,
        pausedUntil: until,
      );

      expect(pausedUntil(null).isPausedAt(now), isFalse);
      expect(
        pausedUntil(now.subtract(const Duration(minutes: 1))).isPausedAt(now),
        isFalse,
      );
      expect(
        pausedUntil(now.add(const Duration(days: 1))).isPausedAt(now),
        isTrue,
      );
    });
  });

  group('ChangePasswordViewModel', () {
    ChangePasswordViewModel fill(
      ProviderContainer c, {
      String old = 'oldpass123',
      String next = 'newpass123',
      String? confirm,
    }) {
      final vm = c.read(changePasswordViewModelProvider.notifier);
      vm.oldPasswordChanged(old);
      vm.newPasswordChanged(next);
      vm.confirmPasswordChanged(confirm ?? next);
      return vm;
    }

    test('client checks block the call', () async {
      final repo = FakeSettingsRepository();
      final c = _container(repo);

      await fill(c, old: '', next: 'short', confirm: 'other').submit();

      final state = c.read(changePasswordViewModelProvider);
      expect(state.oldPasswordError, isNotNull);
      expect(state.newPasswordError, isNotNull);
      expect(state.confirmPasswordError, isNotNull);
      expect(repo.passwordChanges, isEmpty);
    });

    test('WRONG_PASSWORD from the backend is surfaced', () async {
      final repo = FakeSettingsRepository(
        error: const AuthException(
          code: 'WRONG_PASSWORD',
          message: 'Your current password is incorrect.',
        ),
      );
      final c = _container(repo);

      await fill(c).submit();

      final state = c.read(changePasswordViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.isDone, isFalse);
      expect(state.errorCode, 'WRONG_PASSWORD');
      expect(state.errorMessage, 'Your current password is incorrect.');
    });

    test('a valid change sends old and new and finishes', () async {
      final repo = FakeSettingsRepository();
      final c = _container(repo);

      await fill(c).submit();

      expect(repo.passwordChanges.single, (
        old: 'oldpass123',
        next: 'newpass123',
      ));
      expect(c.read(changePasswordViewModelProvider).isDone, isTrue);
    });
  });
}
