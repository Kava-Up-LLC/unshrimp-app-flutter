import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_prefs.dart';
import 'package:move_well_app/core/analytics/event_log.dart';
import 'package:move_well_app/core/config/move_well_app.dart';
import 'package:move_well_app/features/auth/repositories/auth_repository.dart';
import 'package:move_well_app/features/auth/repositories/token_storage.dart';
import 'package:move_well_app/features/break/view_models/break_view_model.dart';
import 'package:move_well_app/features/exercises/repositories/exercises_repository.dart';
import 'package:move_well_app/features/home/repositories/home_repository.dart';
import 'package:move_well_app/features/notifications/repositories/notifications_repository.dart';
import 'package:move_well_app/features/reconcile/repositories/reconcile_repository.dart';
import 'package:move_well_app/features/reminders/repositories/reminder_notifications.dart';
import 'package:move_well_app/features/reminders/repositories/reminder_preferences.dart';
import 'package:move_well_app/features/reminders/services/reminder_scheduler.dart';
import 'package:move_well_app/features/settings/repositories/settings_repository.dart';

import '../auth/fakes.dart';
import '../reconcile/fakes.dart';
import '../home/fakes.dart';
import '../notifications/fakes.dart';
import '../reminders/fakes.dart';
import '../settings/fakes.dart';
import 'fakes.dart';

class _App {
  _App({String? launch, this.realTicks = false})
    : notifications = FakeReminderNotifications(launch: launch);

  /// Uses the app's own one-second ticks instead of [ticks].
  final bool realTicks;

  final FakeReminderNotifications notifications;
  final log = FakeEventLog();
  final ticks = StreamController<void>.broadcast();

  Future<void> pump(WidgetTester tester) async {
    // A phone screen, so the whole break fits.
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reconcileRepositoryProvider.overrideWithValue(FakeReconcileRepository()),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
          notificationsRepositoryProvider.overrideWithValue(
            FakeNotificationsRepository(),
          ),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage('t')),
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository(),
          ),
          exercisesRepositoryProvider.overrideWithValue(
            const FakeExercisesRepository(),
          ),
          reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
          reminderNotificationsProvider.overrideWithValue(notifications),
          reminderPreferencesProvider.overrideWithValue(
            FakeReminderPreferences(asked: true),
          ),
          eventLogProvider.overrideWithValue(log),
          if (!realTicks)
            breakTicksProvider.overrideWithValue(() => ticks.stream),
        ],
        child: const MoveWellApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tick(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      ticks.add(null);
      // Let the broadcast stream deliver (a microtask) before the frame, so
      // each tick's new state is on screen by the time this pump returns. A
      // zero-duration Future would hang: its timer needs the clock pumped.
      await Future<void>.microtask(() {});
      await tester.pump();
    }
  }
}

FilledButton _survived(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Survived'));

Future<void> _start(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Start'));
  await tester.tap(find.text('Start'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(useInMemoryPrefs);

  testWidgets('Take a break now -> Start -> 3-2-1 -> countdown -> Survived', (
    tester,
  ) async {
    final app = _App();
    await app.pump(tester);

    await tester.ensureVisible(find.text('Take a break now'));
    await tester.tap(find.text('Take a break now'));
    await tester.pumpAndSettle();

    // Opens ready: pain_zone from get_settings (FakeSettingsRepository: neck),
    // timer at 60, a Start button, and nothing tracked yet.
    expect(find.text(neckStretch.title), findsOneWidget);
    expect(find.text('60s'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Survived'), findsNothing);
    expect(app.log.events, isEmpty);

    await _start(tester);
    expect(app.log.events, ['break_started']);

    // The 3, 2, 1 count-in, one second each, before the 60 s.
    expect(find.text('3'), findsOneWidget);
    await app.tick(tester, 1);
    expect(find.text('2'), findsOneWidget);
    await app.tick(tester, 1);
    expect(find.text('1'), findsOneWidget);
    await app.tick(tester, 1);
    expect(find.text('60s'), findsOneWidget);

    await app.tick(tester, 60);

    expect(find.text('Done'), findsOneWidget);
    expect(_survived(tester).onPressed, isNotNull);
    expect(app.log.events, ['break_started', 'break_completed']);
    expect(app.log.properties.last, {'source': 'home', 'zone': 'neck'});

    await tester.ensureVisible(find.text('Survived'));
    await tester.tap(find.text('Survived'));
    await tester.pumpAndSettle();

    expect(find.text('Hi Grace Hopper'), findsOneWidget);
    expect(app.log.events, ['break_started', 'break_completed']);
  });

  testWidgets('leaving the break early tracks nothing more', (tester) async {
    final app = _App();
    await app.pump(tester);

    await tester.ensureVisible(find.text('Take a break now'));
    await tester.tap(find.text('Take a break now'));
    await tester.pumpAndSettle();
    await _start(tester);
    await app.tick(tester, 3 + 17);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await app.tick(tester, 60);

    expect(find.text('Hi Grace Hopper'), findsOneWidget);
    expect(app.log.events, ['break_started']);
  });

  testWidgets('a reminder tapped while the app runs opens its break', (
    tester,
  ) async {
    final app = _App();
    await app.pump(tester);

    app.notifications.tapController.add('none');
    await tester.pumpAndSettle();

    // Opens ready and tracks nothing until Start.
    expect(find.text(generalStretch.title), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
    expect(app.log.events, isEmpty);
  });

  testWidgets('a reminder that launched the app opens its break', (
    tester,
  ) async {
    final app = _App(launch: 'neck');
    await app.pump(tester);

    expect(find.text(neckStretch.title), findsOneWidget);
    expect(app.log.events, isEmpty);

    // Back returns to Home.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Hi Grace Hopper'), findsOneWidget);
  });

  // Regression: every break after the first in a session failed with "Bad
  // state: Stream has already been listened to." (one shared tick stream).
  testWidgets('a scheduled reminder tapped after an earlier break opens with '
      'its zone and counts down', (tester) async {
    final app = _App(realTicks: true);
    await app.pump(tester);

    // First break of the session, started then left early.
    await tester.ensureVisible(find.text('Take a break now'));
    await tester.tap(find.text('Take a break now'));
    await tester.pumpAndSettle();
    await _start(tester);
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // A scheduled reminder carries the user's pain_zone as its payload.
    app.notifications.tapController.add('none');
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load the break."), findsNothing);
    expect(find.text(generalStretch.title), findsOneWidget);

    await _start(tester);
    // 3 s count-in, then the 60 s countdown.
    for (var i = 0; i < 3 + 60; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('Done'), findsOneWidget);
    expect(app.log.events, [
      'break_started',
      'break_started',
      'break_completed',
    ]);
    expect(app.log.properties.last, {'source': 'reminder', 'zone': 'none'});
  });
}
