import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_prefs.dart';
import 'package:move_well_app/core/analytics/event_log.dart';
import 'package:move_well_app/features/auth/models/auth_exception.dart';
import 'package:move_well_app/features/auth/repositories/token_storage.dart';
import 'package:move_well_app/features/break/models/break_args.dart';
import 'package:move_well_app/features/break/models/break_phase.dart';
import 'package:move_well_app/features/break/models/break_source.dart';
import 'package:move_well_app/features/break/models/break_state.dart';
import 'package:move_well_app/features/break/view_models/break_view_model.dart';
import 'package:move_well_app/features/exercises/repositories/exercises_repository.dart';
import 'package:move_well_app/features/home/models/user_stats.dart';
import 'package:move_well_app/features/home/repositories/home_repository.dart';
import 'package:move_well_app/features/home/view_models/home_view_model.dart';
import 'package:move_well_app/features/settings/repositories/settings_repository.dart';

import '../auth/fakes.dart';
import '../home/fakes.dart';
import '../reminders/fakes.dart';
import '../settings/fakes.dart';
import 'fakes.dart';

class _Setup {
  _Setup(this.args, {FakeSettingsRepository? settings, FakeHomeRepository? home})
    : settings = settings ?? FakeSettingsRepository(),
      home = home ?? FakeHomeRepository() {
    container = ProviderContainer(
      overrides: [
        eventLogProvider.overrideWithValue(log),
        exercisesRepositoryProvider.overrideWithValue(
          const FakeExercisesRepository(),
        ),
        settingsRepositoryProvider.overrideWithValue(this.settings),
        homeRepositoryProvider.overrideWithValue(this.home),
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
  final FakeHomeRepository home;
  final ticks = StreamController<void>.broadcast();
  late final ProviderContainer container;
  late final ProviderSubscription<Object?> subscription;

  Future<void> tick(int seconds) async {
    for (var i = 0; i < seconds; i++) {
      ticks.add(null);
      await Future<void>.delayed(Duration.zero);
    }
  }

  void start() =>
      container.read(breakViewModelProvider(args).notifier).start();

  BreakState get current =>
      container.read(breakViewModelProvider(args)).requireValue;

  int get secondsLeft => current.secondsLeft;
}

void main() {
  setUp(useInMemoryPrefs);

  const fromReminder = BreakArgs(source: BreakSource.reminder, zone: 'neck');

  test('opening tracks nothing and shows the zone stretch at 60', () async {
    final s = _Setup(fromReminder);

    final state = await s.container.read(
      breakViewModelProvider(fromReminder).future,
    );

    expect(s.log.events, isEmpty);
    expect(state.exercise, same(neckStretch));
    expect(state.phase, BreakPhase.ready);
    expect(state.secondsLeft, 60);
    expect(state.isCompleted, isFalse);
  });

  test('Start tracks break_started and begins the count-in', () async {
    final s = _Setup(fromReminder);
    await s.container.read(breakViewModelProvider(fromReminder).future);

    s.start();

    expect(s.log.events, ['break_started']);
    expect(s.log.properties.single, {'source': 'reminder', 'zone': 'neck'});
    expect(s.current.phase, BreakPhase.countingIn);
    expect(s.current.countInLeft, 3);
    expect(s.secondsLeft, 60);
  });

  test('the 3-2-1 count-in runs before the 60 s countdown', () async {
    final s = _Setup(fromReminder);
    await s.container.read(breakViewModelProvider(fromReminder).future);
    s.start();

    await s.tick(1);
    expect(s.current.countInLeft, 2);
    expect(s.current.phase, BreakPhase.countingIn);

    await s.tick(1);
    expect(s.current.countInLeft, 1);
    expect(s.current.phase, BreakPhase.countingIn);

    // The third count-in tick starts the 60 s, still full.
    await s.tick(1);
    expect(s.current.phase, BreakPhase.running);
    expect(s.secondsLeft, 60);

    await s.tick(1);
    expect(s.secondsLeft, 59);
  });

  test('reaching 0 tracks break_completed exactly once', () async {
    final s = _Setup(fromReminder);
    await s.container.read(breakViewModelProvider(fromReminder).future);
    s.start();

    // 3 count-in ticks, then the countdown begins.
    await s.tick(3);
    await s.tick(59);
    expect(s.secondsLeft, 1);
    expect(s.current.phase, BreakPhase.running);
    expect(s.log.events, ['break_started']);

    await s.tick(5);
    expect(s.secondsLeft, 0);
    expect(s.current.phase, BreakPhase.done);
    expect(s.log.events, ['break_started', 'break_completed']);
    expect(s.log.properties.last, {'source': 'reminder', 'zone': 'neck'});
  });

  test('leaving before 0 never tracks break_completed', () async {
    final s = _Setup(fromReminder);
    await s.container.read(breakViewModelProvider(fromReminder).future);
    s.start();
    await s.tick(3 + 30);

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
    expect(s.log.events, isEmpty);

    // The zone is carried into break_started on Start.
    s.start();
    expect(s.log.properties.single, {'source': 'home', 'zone': 'neck'});
  });

  test('registerBreak reports the break and pushes the row into Home', () async {
    const afterBreak = UserStats(
      userId: 3,
      name: 'Grace Hopper',
      archetype: null,
      currentStreak: 5,
      breaksToday: 3,
      ignoredCount: 0,
      roastLevel: 2,
      roastPending: false,
    );
    final s = _Setup(
      fromReminder,
      home: FakeHomeRepository(afterBreak: afterBreak),
    );
    await s.container.read(breakViewModelProvider(fromReminder).future);

    // Let Home finish its first load (testStats) before the break reports in,
    // so applyStats isn't overwritten by the initial build.
    final homeSub = s.container.listen(homeViewModelProvider, (_, _) {});
    await s.container.read(homeViewModelProvider.future);

    await s.container
        .read(breakViewModelProvider(fromReminder).notifier)
        .registerBreak();

    expect(s.home.breakCalls, 1);
    expect(s.container.read(homeViewModelProvider).value, same(afterBreak));
    homeSub.close();
  });

  test('settings unavailable: a general stretch', () async {
    const fromHome = BreakArgs(source: BreakSource.home);
    final s = _Setup(
      fromHome,
      settings: FakeSettingsRepository(
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
