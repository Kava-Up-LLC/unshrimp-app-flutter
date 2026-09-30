import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_well_app/core/analytics/event_log.dart';
import 'package:move_well_app/core/config/move_well_app.dart';
import 'package:move_well_app/features/auth/repositories/auth_repository.dart';
import 'package:move_well_app/features/auth/repositories/token_storage.dart';
import 'package:move_well_app/features/break/view_models/break_view_model.dart';
import 'package:move_well_app/features/exercises/repositories/exercises_repository.dart';
import 'package:move_well_app/features/home/repositories/home_repository.dart';
import 'package:move_well_app/features/notifications/repositories/delivery_log.dart';
import 'package:move_well_app/features/notifications/repositories/notifications_repository.dart';
import 'package:move_well_app/features/reminders/repositories/reminder_notifications.dart';
import 'package:move_well_app/features/reminders/repositories/reminder_preferences.dart';
import 'package:move_well_app/features/reminders/services/reminder_scheduler.dart';
import 'package:move_well_app/features/settings/repositories/settings_repository.dart';

import '../auth/fakes.dart';
import '../break/fakes.dart';
import '../home/fakes.dart';
import '../reminders/fakes.dart';
import '../settings/fakes.dart';
import 'fakes.dart';

void main() {
  testWidgets('Home bell -> Center -> tap a reminder opens the break and '
      'marks it read', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    final rows = FakeNotificationsRepository(
      rows: [
        notification(1, DateTime.utc(2026, 9, 29, 9), read: true),
        notification(2, DateTime.utc(2026, 9, 29, 10)),
      ],
    );
    final log = FakeEventLog();
    final ticks = StreamController<void>.broadcast();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage('t')),
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository(),
          ),
          exercisesRepositoryProvider.overrideWithValue(
            const FakeExercisesRepository(),
          ),
          notificationsRepositoryProvider.overrideWithValue(rows),
          deliveryLogProvider.overrideWithValue(FakeDeliveryLog()),
          reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
          reminderNotificationsProvider.overrideWithValue(
            FakeReminderNotifications(),
          ),
          reminderPreferencesProvider.overrideWithValue(
            FakeReminderPreferences(asked: true),
          ),
          eventLogProvider.overrideWithValue(log),
          breakTicksProvider.overrideWithValue(() => ticks.stream),
        ],
        child: const MoveWellApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Notifications, unread'));
    await tester.pumpAndSettle();

    // Newest first.
    final line2 = tester.getTopLeft(find.text('Line 2')).dy;
    final line1 = tester.getTopLeft(find.text('Line 1')).dy;
    expect(line2, lessThan(line1));
    expect(find.bySemanticsLabel(RegExp('Unread')), findsOneWidget);

    await tester.tap(find.text('Line 2'));
    await tester.pumpAndSettle();

    expect(find.text('Micro-break'), findsOneWidget);
    // pain_zone comes from get_settings (neck).
    expect(find.text(neckStretch.title), findsOneWidget);
    expect(log.properties.last, {'source': 'center'});
    expect(rows.markedRead, [2]);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Unread')), findsNothing);
    semantics.dispose();
  });
}
