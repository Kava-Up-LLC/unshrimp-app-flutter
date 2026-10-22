import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/subscriptions/repositories/entitlement_repository.dart';

import '../subscriptions/fakes.dart';

import '../../support/in_memory_prefs.dart';
import 'package:unshrimp_app/core/analytics/event_log.dart';
import 'package:unshrimp_app/core/config/unshrimp_app.dart';
import 'package:unshrimp_app/core/theme/app_colors.dart';
import 'package:unshrimp_app/features/roast/views/roast_view.dart';
import 'package:unshrimp_app/features/auth/repositories/auth_repository.dart';
import 'package:unshrimp_app/features/auth/repositories/token_storage.dart';
import 'package:unshrimp_app/features/break/view_models/break_view_model.dart';
import 'package:unshrimp_app/features/exercises/repositories/exercises_repository.dart';
import 'package:unshrimp_app/features/home/models/user_stats.dart';
import 'package:unshrimp_app/features/home/repositories/home_repository.dart';
import 'package:unshrimp_app/features/notifications/repositories/notifications_repository.dart';
import 'package:unshrimp_app/features/reconcile/repositories/reconcile_repository.dart';
import 'package:unshrimp_app/features/reminders/repositories/reminder_notifications.dart';
import 'package:unshrimp_app/features/reminders/repositories/reminder_preferences.dart';
import 'package:unshrimp_app/features/reminders/services/reminder_scheduler.dart';
import 'package:unshrimp_app/features/roast/repositories/roast_lines_repository.dart';
import 'package:unshrimp_app/features/settings/repositories/settings_repository.dart';

import '../auth/fakes.dart';
import '../break/fakes.dart';
import '../home/fakes.dart';
import '../notifications/fakes.dart';
import '../reconcile/fakes.dart';
import '../reminders/fakes.dart';
import '../settings/fakes.dart';

const _pending = UserStats(
  userId: 7,
  name: 'Oliver H',
  archetype: null,
  currentStreak: 0,
  breaksToday: 0,
  ignoredCount: 3,
  roastLevel: 3,
  roastPending: true,
);

const _cleared = UserStats(
  userId: 7,
  name: 'Oliver H',
  archetype: null,
  currentStreak: 0,
  breaksToday: 1,
  ignoredCount: 0,
  roastLevel: 0,
  roastPending: false,
);

void main() {
  setUp(useInMemoryPrefs);

  testWidgets('roast_pending routes to the roast; Fix my posture + Survived '
      'returns to Home cleared', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final ticks = StreamController<void>.broadcast();
    addTearDown(ticks.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entitlementRepositoryProvider.overrideWithValue(FakeEntitlementRepository()),
          reconcileRepositoryProvider.overrideWithValue(FakeReconcileRepository()),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          // Launch with roast_pending true; a survived break clears it.
          homeRepositoryProvider.overrideWithValue(
            FakeHomeRepository(stats: _pending, afterBreak: _cleared),
          ),
          notificationsRepositoryProvider.overrideWithValue(
            FakeNotificationsRepository(),
          ),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage('t')),
          settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
          exercisesRepositoryProvider.overrideWithValue(
            const FakeExercisesRepository(),
          ),
          reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
          reminderNotificationsProvider.overrideWithValue(
            FakeReminderNotifications(),
          ),
          reminderPreferencesProvider.overrideWithValue(
            FakeReminderPreferences(asked: true),
          ),
          roastLinesRepositoryProvider.overrideWithValue(
            RoastLinesRepository(
              FakeReminderPreferences(),
              readConfig: (_) async => '["Your chair adopted you."]',
            ),
          ),
          eventLogProvider.overrideWithValue(FakeEventLog()),
          breakTicksProvider.overrideWithValue(() => ticks.stream),
        ],
        child: const UnshrimpApp(),
      ),
    );
    await tester.pumpAndSettle();

    // The roast is shown instead of Home, on the coral container background.
    expect(find.text('Your chair adopted you.'), findsOneWidget);
    expect(find.text('Fix my posture'), findsOneWidget);
    expect(find.text('Hi Oliver H'), findsNothing);
    final roastScaffold = tester.widget<Scaffold>(
      find.descendant(of: find.byType(RoastView), matching: find.byType(Scaffold)),
    );
    expect(roastScaffold.backgroundColor, AppColors.coralContainerDark);

    // Fix my posture opens the break.
    await tester.tap(find.text('Fix my posture'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);

    await tester.ensureVisible(find.text('Start'));
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3 + 60; i++) {
      ticks.add(null);
      await Future<void>.microtask(() {});
      await tester.pump();
    }

    await tester.ensureVisible(find.text('Survived'));
    await tester.tap(find.text('Survived'));
    await tester.pumpAndSettle();

    // Back to Home with cleared stats; no roast.
    expect(find.text('Hi Oliver H'), findsOneWidget);
    expect(find.text('Fix my posture'), findsNothing);
    expect(find.text('100%'), findsOneWidget); // roast_level 0 -> full battery
  });
}
