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
import 'package:move_well_app/features/home/widgets/notifications_bell.dart';
import 'package:move_well_app/features/notifications/models/app_notification.dart';
import 'package:move_well_app/features/notifications/repositories/delivery_log.dart';
import 'package:move_well_app/features/notifications/repositories/notifications_repository.dart';
import 'package:move_well_app/features/reminders/models/reminder_payload.dart';
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

AppNotification _row(int id, String key, {bool read = false}) =>
    AppNotification(
      id: id,
      title: 'MoveWell',
      body: 'Line $id',
      pack: 'default',
      sentAt: DateTime.utc(2026, 9, 29, 9 + id),
      read: read,
      reminderKey: key,
    );

String _tapped(String key) => ReminderPayload(zone: 'neck', key: key).encode();

final _dot = find.byKey(NotificationsBell.dotKey);

Future<FakeReminderNotifications> _pumpApp(
  WidgetTester tester,
  FakeNotificationsRepository rows, {
  String? launch,
}) async {
  tester.view.physicalSize = const Size(1290, 2796);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final notifications = FakeReminderNotifications(launch: launch);
  final ticks = StreamController<void>.broadcast();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
        tokenStorageProvider.overrideWithValue(FakeTokenStorage('t')),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        exercisesRepositoryProvider.overrideWithValue(
          const FakeExercisesRepository(),
        ),
        notificationsRepositoryProvider.overrideWithValue(rows),
        deliveryLogProvider.overrideWithValue(FakeDeliveryLog()),
        reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
        reminderNotificationsProvider.overrideWithValue(notifications),
        reminderPreferencesProvider.overrideWithValue(
          FakeReminderPreferences(asked: true),
        ),
        eventLogProvider.overrideWithValue(FakeEventLog()),
        breakTicksProvider.overrideWithValue(() => ticks.stream),
      ],
      child: const MoveWellApp(),
    ),
  );
  await tester.pumpAndSettle();
  return notifications;
}

Future<void> _backToHome(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Back'));
  await tester.pumpAndSettle();
  expect(find.text('Hi Grace Hopper'), findsOneWidget);
}

void main() {
  testWidgets('warm tap: marks its own row read and clears the dot when it '
      'was the last unread', (tester) async {
    final rows = FakeNotificationsRepository(
      rows: [_row(1, 'd1-0', read: true), _row(2, 'd1-1')],
    );
    final notifications = await _pumpApp(tester, rows);
    expect(_dot, findsOneWidget);

    notifications.tapController.add(_tapped('d1-1'));
    await tester.pumpAndSettle();

    expect(find.text(neckStretch.title), findsOneWidget);
    expect(rows.markedRead, [2]);
    await _backToHome(tester);
    expect(_dot, findsNothing);
  });

  testWidgets('warm tap: never marks other rows', (tester) async {
    final rows = FakeNotificationsRepository(
      rows: [_row(1, 'd1-0'), _row(2, 'd1-1'), _row(3, 'd1-2')],
    );
    final notifications = await _pumpApp(tester, rows);

    notifications.tapController.add(_tapped('d1-1'));
    await tester.pumpAndSettle();

    expect(rows.markedRead, [2]);
    expect(rows.rows.where((n) => !n.read).map((n) => n.id), [1, 3]);
    await _backToHome(tester);
    // Others are still unread.
    expect(_dot, findsOneWidget);
  });

  testWidgets('cold start: the launching reminder\'s row is marked read', (
    tester,
  ) async {
    final rows = FakeNotificationsRepository(
      rows: [_row(1, 'd1-0', read: true), _row(2, 'd1-1')],
    );
    await _pumpApp(tester, rows, launch: _tapped('d1-1'));

    expect(find.text(neckStretch.title), findsOneWidget);
    expect(rows.markedRead, [2]);
    await _backToHome(tester);
    expect(_dot, findsNothing);
  });

  testWidgets('a tap with no matching row marks nothing', (tester) async {
    final rows = FakeNotificationsRepository(rows: [_row(1, 'd1-0')]);
    final notifications = await _pumpApp(tester, rows);

    notifications.tapController.add(_tapped('d9-9'));
    await tester.pumpAndSettle();

    expect(find.text(neckStretch.title), findsOneWidget);
    expect(rows.markedRead, isEmpty);
    await _backToHome(tester);
    expect(_dot, findsOneWidget);
  });
}
