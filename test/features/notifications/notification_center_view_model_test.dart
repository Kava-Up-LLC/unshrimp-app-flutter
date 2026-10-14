import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/core/analytics/event_log.dart';
import 'package:unshrimp_app/features/auth/models/auth_exception.dart';
import 'package:unshrimp_app/features/auth/repositories/token_storage.dart';
import 'package:unshrimp_app/features/notifications/models/scheduled_reminder.dart';
import 'package:unshrimp_app/features/notifications/repositories/delivery_log.dart';
import 'package:unshrimp_app/features/notifications/repositories/notifications_repository.dart';
import 'package:unshrimp_app/features/notifications/view_models/notification_center_view_model.dart';
import 'package:unshrimp_app/features/reminders/repositories/reminder_notifications.dart';

import '../auth/fakes.dart';
import '../reminders/fakes.dart';
import 'fakes.dart';

ProviderContainer _container(
  FakeNotificationsRepository rows, [
  FakeDeliveryLog? deliveryLog,
]) {
  final container = ProviderContainer(
    overrides: [
      notificationsRepositoryProvider.overrideWithValue(rows),
      deliveryLogProvider.overrideWithValue(deliveryLog ?? FakeDeliveryLog()),
      tokenStorageProvider.overrideWithValue(FakeTokenStorage('t')),
      reminderNotificationsProvider.overrideWithValue(
        FakeReminderNotifications(),
      ),
      eventLogProvider.overrideWithValue(FakeEventLog()),
    ],
  );
  addTearDown(container.dispose);
  container.listen(notificationCenterViewModelProvider, (_, _) {});
  return container;
}

void main() {
  test(
    'lists newest first, including reminders shown since the last sync',
    () async {
      final rows = FakeNotificationsRepository(
        rows: [notification(1, DateTime.utc(2026, 9, 28, 9), read: true)],
      );
      final deliveryLog = FakeDeliveryLog(
        schedule: [
          ScheduledReminder.once(
            key: 'k-once',
            at: DateTime.now().subtract(const Duration(minutes: 1)),
            body: 'Boo.',
            pack: 'halloween',
            scheduledAt: DateTime.now().subtract(const Duration(minutes: 2)),
          ),
        ],
      );
      final c = _container(rows, deliveryLog);

      final list = await c.read(notificationCenterViewModelProvider.future);

      expect(list.map((n) => (n.body, n.pack, n.read)), [
        ('Boo.', 'halloween', false),
        ('Line 1', 'default', true),
      ]);
    },
  );

  test('opening an unread row marks it read', () async {
    final rows = FakeNotificationsRepository(
      rows: [notification(7, DateTime.utc(2026, 9, 29, 10))],
    );
    final c = _container(rows);
    final list = await c.read(notificationCenterViewModelProvider.future);

    await c
        .read(notificationCenterViewModelProvider.notifier)
        .opened(list.single);

    expect(rows.markedRead, [7]);
    expect(
      c.read(notificationCenterViewModelProvider).requireValue.single.read,
      isTrue,
    );
  });

  test('a read row is not marked again', () async {
    final rows = FakeNotificationsRepository(
      rows: [notification(7, DateTime.utc(2026, 9, 29, 10), read: true)],
    );
    final c = _container(rows);
    final list = await c.read(notificationCenterViewModelProvider.future);

    await c
        .read(notificationCenterViewModelProvider.notifier)
        .opened(list.single);

    expect(rows.markedRead, isEmpty);
  });

  test('a rejected mark shows the row unread again', () async {
    final rows = FakeNotificationsRepository(
      rows: [notification(7, DateTime.utc(2026, 9, 29, 10))],
    );
    final c = _container(rows);
    final list = await c.read(notificationCenterViewModelProvider.future);
    rows.error = const AuthException(code: 'NOT_FOUND', message: 'gone');

    await c
        .read(notificationCenterViewModelProvider.notifier)
        .opened(list.single);

    expect(
      c.read(notificationCenterViewModelProvider).requireValue.single.read,
      isFalse,
    );
  });

  test('mark all read marks every row read', () async {
    final rows = FakeNotificationsRepository(
      rows: [
        notification(1, DateTime.utc(2026, 9, 29, 10)),
        notification(2, DateTime.utc(2026, 9, 29, 11)),
      ],
    );
    final c = _container(rows);
    await c.read(notificationCenterViewModelProvider.future);

    await c.read(notificationCenterViewModelProvider.notifier).markAllRead();

    expect(rows.markAllReadCalls, 1);
    expect(
      c
          .read(notificationCenterViewModelProvider)
          .requireValue
          .every((n) => n.read),
      isTrue,
    );
  });

  test('delete removes the row from the list', () async {
    final rows = FakeNotificationsRepository(
      rows: [
        notification(1, DateTime.utc(2026, 9, 29, 10)),
        notification(2, DateTime.utc(2026, 9, 29, 11)),
      ],
    );
    final c = _container(rows);
    final list = await c.read(notificationCenterViewModelProvider.future);

    await c
        .read(notificationCenterViewModelProvider.notifier)
        .delete(list.firstWhere((n) => n.id == 1));

    expect(rows.deleted, [1]);
    expect(
      c.read(notificationCenterViewModelProvider).requireValue.map((n) => n.id),
      [2],
    );
  });

  test('a rejected delete restores the row', () async {
    final rows = FakeNotificationsRepository(
      rows: [notification(1, DateTime.utc(2026, 9, 29, 10))],
    );
    final c = _container(rows);
    final list = await c.read(notificationCenterViewModelProvider.future);
    rows.error = const AuthException(code: 'NOT_FOUND', message: 'gone');

    await c.read(notificationCenterViewModelProvider.notifier).delete(list.single);

    expect(
      c.read(notificationCenterViewModelProvider).requireValue.map((n) => n.id),
      [1],
    );
  });
}
