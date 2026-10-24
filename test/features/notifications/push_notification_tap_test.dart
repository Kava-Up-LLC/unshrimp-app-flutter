import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:unshrimp_app/core/analytics/event_log.dart';
import 'package:unshrimp_app/features/auth/repositories/token_storage.dart';
import 'package:unshrimp_app/features/notifications/models/app_notification.dart';
import 'package:unshrimp_app/features/notifications/repositories/delivery_log.dart';
import 'package:unshrimp_app/features/notifications/repositories/notifications_repository.dart';
import 'package:unshrimp_app/features/notifications/views/notification_center_view.dart';
import 'package:unshrimp_app/features/reminders/repositories/reminder_notifications.dart';

import '../auth/fakes.dart';
import '../reminders/fakes.dart';
import 'fakes.dart';

Future<void> _pumpCenter(WidgetTester tester, FakeNotificationsRepository repo) async {
  final router = GoRouter(
    initialLocation: '/notifications',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
      GoRoute(path: '/history', builder: (_, _) => const Text('HISTORY')),
      GoRoute(path: '/break', builder: (_, _) => const Text('BREAK')),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationCenterView(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationsRepositoryProvider.overrideWithValue(repo),
        deliveryLogProvider.overrideWithValue(FakeDeliveryLog()),
        tokenStorageProvider.overrideWithValue(FakeTokenStorage('t')),
        reminderNotificationsProvider.overrideWithValue(FakeReminderNotifications()),
        eventLogProvider.overrideWithValue(FakeEventLog()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping a push row navigates by its open key', (tester) async {
    final repo = FakeNotificationsRepository(
      rows: [
        AppNotification(
          id: 1,
          title: 'Spine',
          body: 'See your report',
          pack: '',
          sentAt: DateTime.utc(2026, 10, 20, 9),
          read: false,
          kind: 'push',
          open: 'history',
        ),
      ],
    );
    await _pumpCenter(tester, repo);

    await tester.tap(find.text('See your report'));
    await tester.pumpAndSettle();

    expect(find.text('HISTORY'), findsOneWidget);
    expect(find.text('BREAK'), findsNothing);
  });

  testWidgets('tapping a reminder row opens the break', (tester) async {
    final repo = FakeNotificationsRepository(
      rows: [notification(1, DateTime.utc(2026, 10, 20, 9))],
    );
    await _pumpCenter(tester, repo);

    await tester.tap(find.text('Line 1'));
    await tester.pumpAndSettle();

    expect(find.text('BREAK'), findsOneWidget);
    expect(find.text('HISTORY'), findsNothing);
  });
}
