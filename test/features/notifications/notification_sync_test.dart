import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/auth/models/auth_exception.dart';
import 'package:unshrimp_app/features/notifications/models/scheduled_reminder.dart';
import 'package:unshrimp_app/features/notifications/services/notification_sync.dart';

import '../auth/fakes.dart';
import '../reminders/fakes.dart';
import 'fakes.dart';

final _scheduledAt = DateTime(2026, 9, 29, 8);

NotificationSync _sync(
  FakeDeliveryLog deliveryLog,
  FakeNotificationsRepository rows, {
  DateTime? now,
  bool enabled = true,
  String? token = 't',
}) => NotificationSync(
  deliveryLog: deliveryLog,
  repository: rows,
  tokens: FakeTokenStorage(token),
  notifications: FakeReminderNotifications(enabled: enabled),
  log: FakeEventLog(),
  now: () => now ?? DateTime(2026, 9, 29, 11, 30),
);

FakeDeliveryLog _log() => FakeDeliveryLog(
  schedule: [
    for (final h in [10, 11, 12])
      ScheduledReminder.daily(
        key: 'k-daily',
        hour: h,
        minute: 0,
        body: 'Line $h',
        pack: 'halloween',
        scheduledAt: _scheduledAt,
      ),
  ],
);

void main() {
  test('sends the shown reminders in one batch and moves on', () async {
    final log = _log();
    final rows = FakeNotificationsRepository();

    await _sync(log, rows).sync();

    expect(rows.logged.single.map((r) => (r.title, r.body, r.pack)), [
      ('Unshrimp', 'Line 10', 'halloween'),
      ('Unshrimp', 'Line 11', 'halloween'),
    ]);
    expect(log.lastSync, DateTime(2026, 9, 29, 11, 30));

    // Nothing new since: nothing sent twice.
    await _sync(log, rows).sync();
    expect(rows.logged, hasLength(1));
  });

  test('a failed call keeps them for the next sync', () async {
    final log = _log();
    final rows = FakeNotificationsRepository(
      error: const AuthException(code: 'NETWORK', message: 'offline'),
    );

    await _sync(log, rows).sync();
    expect(log.lastSync, isNull);

    rows.error = null;
    await _sync(log, rows).sync();
    expect(rows.logged.single, hasLength(2));
  });

  test('overlapping syncs send once', () async {
    final log = _log();
    final rows = FakeNotificationsRepository();
    final sync = _sync(log, rows);

    await Future.wait([sync.sync(), sync.sync()]);

    expect(rows.logged, hasLength(1));
  });

  test('notifications turned off: nothing was shown, nothing logged', () async {
    final log = _log();
    final rows = FakeNotificationsRepository();

    await _sync(log, rows, enabled: false).sync();

    expect(rows.logged, isEmpty);
    expect(log.lastSync, isNotNull);
  });

  test('a fired one-off reminder is logged, then dropped', () async {
    final log = FakeDeliveryLog(
      schedule: [
        ScheduledReminder.once(
          key: 'k-once',
          at: DateTime(2026, 9, 29, 8, 0, 5),
          body: 'Boo.',
          pack: 'halloween',
          scheduledAt: _scheduledAt,
        ),
      ],
    );
    final rows = FakeNotificationsRepository();

    await _sync(log, rows).sync();

    expect(rows.logged.single.single.body, 'Boo.');
    expect(log.schedule, isEmpty);
  });

  test('logged out: does nothing', () async {
    final log = _log();
    final rows = FakeNotificationsRepository();

    await _sync(log, rows, token: null).sync();

    expect(rows.logged, isEmpty);
    expect(log.lastSync, isNull);
  });
}
