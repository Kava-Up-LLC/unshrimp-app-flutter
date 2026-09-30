import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_well_app/core/analytics/event_log.dart';
import 'package:move_well_app/features/auth/models/auth_exception.dart';
import 'package:move_well_app/features/auth/repositories/token_storage.dart';
import 'package:move_well_app/features/break/models/break_args.dart';
import 'package:move_well_app/features/break/models/break_source.dart';
import 'package:move_well_app/features/break/view_models/break_view_model.dart';
import 'package:move_well_app/features/exercises/repositories/exercises_repository.dart';
import 'package:move_well_app/features/settings/repositories/settings_repository.dart';

import '../auth/fakes.dart';
import '../reminders/fakes.dart';
import '../settings/fakes.dart';
import 'fakes.dart';

class _Setup {
  _Setup(this.args, [FakeSettingsRepository? settings])
    : settings = settings ?? FakeSettingsRepository() {
    container = ProviderContainer(
      overrides: [
        eventLogProvider.overrideWithValue(log),
        exercisesRepositoryProvider.overrideWithValue(
          const FakeExercisesRepository(),
        ),
        settingsRepositoryProvider.overrideWithValue(this.settings),
        tokenStorageProvider.overrideWithValue(FakeTokenStorage('t')),
        breakTicksProvider.overrideWithValue(() => ticks.stream),
      ],
    );
    addTearDown(container.dispose);
    subscription = container.listen(breakViewModelProvider(args), (_, _) {});
  }

  final BreakArgs args;
  final log = FakeEventLog();
  final FakeSettingsRepository settings;
  final ticks = StreamController<void>.broadcast();
  late final ProviderContainer container;
  late final ProviderSubscription<Object?> subscription;

  Future<void> tick(int seconds) async {
    for (var i = 0; i < seconds; i++) {
      ticks.add(null);
      await Future<void>.delayed(Duration.zero);
    }
  }

  int get secondsLeft =>
      container.read(breakViewModelProvider(args)).requireValue.secondsLeft;
}

void main() {
  const fromReminder = BreakArgs(source: BreakSource.reminder, zone: 'neck');

  test('opening tracks break_started and shows the zone stretch', () async {
    final s = _Setup(fromReminder);

    final state = await s.container.read(
      breakViewModelProvider(fromReminder).future,
    );

    expect(s.log.events, ['break_started']);
    expect(s.log.properties.single, {'source': 'reminder', 'zone': 'neck'});
    expect(state.exercise, same(neckStretch));
    expect(state.secondsLeft, 60);
    expect(state.isCompleted, isFalse);
  });

  test('reaching 0 tracks break_completed exactly once', () async {
    final s = _Setup(fromReminder);
    await s.container.read(breakViewModelProvider(fromReminder).future);

    await s.tick(59);
    expect(s.secondsLeft, 1);
    expect(s.log.events, ['break_started']);

    await s.tick(5);
    expect(s.secondsLeft, 0);
    expect(s.log.events, ['break_started', 'break_completed']);
    expect(s.log.properties.last, {'source': 'reminder', 'zone': 'neck'});
  });

  test('leaving before 0 never tracks break_completed', () async {
    final s = _Setup(fromReminder);
    await s.container.read(breakViewModelProvider(fromReminder).future);
    await s.tick(30);

    s.subscription.close();
    await Future<void>.delayed(Duration.zero);
    await s.tick(60);

    expect(s.log.events, ['break_started']);
  });

  test('without a zone, reads pain_zone from get_settings', () async {
    const fromHome = BreakArgs(source: BreakSource.home);
    final s = _Setup(fromHome);

    final state = await s.container.read(
      breakViewModelProvider(fromHome).future,
    );

    expect(state.zone, 'neck');
    expect(s.log.properties.single, {'source': 'home'});
  });

  test('settings unavailable: a general stretch', () async {
    const fromHome = BreakArgs(source: BreakSource.home);
    final s = _Setup(
      fromHome,
      FakeSettingsRepository(
        fetchError: const AuthException(code: 'NETWORK', message: 'offline'),
      ),
    );

    final state = await s.container.read(
      breakViewModelProvider(fromHome).future,
    );

    expect(state.zone, 'none');
    expect(state.exercise, same(generalStretch));
  });
}
