import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/core/analytics/event_log.dart';
import 'package:unshrimp_app/core/config/unshrimp_app.dart';
import 'package:unshrimp_app/features/auth/repositories/auth_repository.dart';
import 'package:unshrimp_app/features/auth/repositories/token_storage.dart';
import 'package:unshrimp_app/features/home/repositories/home_repository.dart';
import 'package:unshrimp_app/features/home/widgets/notifications_bell.dart';
import 'package:unshrimp_app/features/notifications/models/scheduled_reminder.dart';
import 'package:unshrimp_app/features/notifications/repositories/delivery_log.dart';
import 'package:unshrimp_app/features/notifications/repositories/notifications_repository.dart';
import 'package:unshrimp_app/features/notifications/view_models/has_unread_notifications_view_model.dart';
import 'package:unshrimp_app/features/reconcile/repositories/reconcile_repository.dart';
import 'package:unshrimp_app/features/reminders/repositories/reminder_notifications.dart';
import 'package:unshrimp_app/features/reminders/repositories/reminder_preferences.dart';
import 'package:unshrimp_app/features/reminders/services/reminder_scheduler.dart';

import '../auth/fakes.dart';
import '../reconcile/fakes.dart';
import '../home/fakes.dart';
import '../reminders/fakes.dart';
import 'fakes.dart';

final _earlier = DateTime.utc(2026, 9, 29, 9);

List<Override> _overrides(
  FakeNotificationsRepository rows, [
  FakeDeliveryLog? deliveryLog,
]) => [
  notificationsRepositoryProvider.overrideWithValue(rows),
  deliveryLogProvider.overrideWithValue(deliveryLog ?? FakeDeliveryLog()),
  tokenStorageProvider.overrideWithValue(FakeTokenStorage('t')),
  reminderNotificationsProvider.overrideWithValue(FakeReminderNotifications()),
  eventLogProvider.overrideWithValue(FakeEventLog()),
];

Future<void> _pumpHome(
  WidgetTester tester,
  FakeNotificationsRepository rows,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reconcileRepositoryProvider.overrideWithValue(FakeReconcileRepository()),
        ..._overrides(rows),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
        reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
        reminderPreferencesProvider.overrideWithValue(
          FakeReminderPreferences(asked: true),
        ),
      ],
      child: const UnshrimpApp(),
    ),
  );
  await tester.pumpAndSettle();
}

final _dot = find.byKey(NotificationsBell.dotKey);

void main() {
  group('hasUnreadNotificationsProvider', () {
    Future<bool> read(
      FakeNotificationsRepository rows, [
      FakeDeliveryLog? log,
    ]) {
      final c = ProviderContainer(overrides: _overrides(rows, log));
      addTearDown(c.dispose);
      c.listen(hasUnreadNotificationsProvider, (_, _) {});
      return c.read(hasUnreadNotificationsProvider.future);
    }

    test('true with at least one unread row', () async {
      expect(
        await read(
          FakeNotificationsRepository(
            rows: [
              notification(1, _earlier, read: true),
              notification(2, _earlier),
            ],
          ),
        ),
        isTrue,
      );
    });

    test('false when every row is read, or there are none', () async {
      expect(
        await read(
          FakeNotificationsRepository(
            rows: [notification(1, _earlier, read: true)],
          ),
        ),
        isFalse,
      );
      expect(await read(FakeNotificationsRepository()), isFalse);
    });

    test('counts a reminder shown since the last sync', () async {
      final now = DateTime.now();
      final log = FakeDeliveryLog(
        schedule: [
          ScheduledReminder.once(
            key: 'k-once',
            at: now.subtract(const Duration(minutes: 1)),
            body: 'Boo.',
            pack: 'halloween',
            scheduledAt: now.subtract(const Duration(minutes: 2)),
          ),
        ],
      );

      expect(await read(FakeNotificationsRepository(), log), isTrue);
    });
  });

  group('Home bell dot', () {
    testWidgets('shows while there is an unread notification', (tester) async {
      await _pumpHome(
        tester,
        FakeNotificationsRepository(rows: [notification(1, _earlier)]),
      );

      expect(_dot, findsOneWidget);
      expect(find.byTooltip('Notifications, unread'), findsOneWidget);
    });

    testWidgets('hidden when everything is read', (tester) async {
      await _pumpHome(
        tester,
        FakeNotificationsRepository(
          rows: [notification(1, _earlier, read: true)],
        ),
      );

      expect(_dot, findsNothing);
      expect(find.byTooltip('Notifications'), findsOneWidget);
    });

    testWidgets('disappears after the last unread is marked read in the '
        'Center', (tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final rows = FakeNotificationsRepository(
        rows: [
          notification(1, _earlier, read: true),
          notification(2, _earlier.add(const Duration(hours: 1))),
        ],
      );
      await _pumpHome(tester, rows);
      expect(_dot, findsOneWidget);

      await tester.tap(find.byTooltip('Notifications, unread'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Line 2'));
      await tester.pumpAndSettle();
      // The break opened on top; back to the Center, then Home.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(rows.markedRead, [2]);
      expect(find.text('Hi Grace Hopper'), findsOneWidget);
      expect(_dot, findsNothing);
    });

    testWidgets('appears when the app returns with a new unread row', (
      tester,
    ) async {
      final rows = FakeNotificationsRepository(
        rows: [notification(1, _earlier, read: true)],
      );
      await _pumpHome(tester, rows);
      expect(_dot, findsNothing);

      // A reminder was logged while the app was in the background.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      rows.rows.add(notification(2, _earlier.add(const Duration(hours: 1))));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(_dot, findsOneWidget);
    });
  });
}
