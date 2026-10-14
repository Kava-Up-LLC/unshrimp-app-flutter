import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/notifications/models/app_notification.dart';
import 'package:unshrimp_app/features/notifications/models/scheduled_reminder.dart';
import 'package:unshrimp_app/features/notifications/services/notification_sync.dart';
import 'package:unshrimp_app/features/notifications/services/reminder_opened_marker.dart';

import '../auth/fakes.dart';
import '../reminders/fakes.dart';
import 'fakes.dart';

final _now = DateTime.utc(2026, 9, 29, 15);

AppNotification _row(
  int id,
  String? key,
  DateTime sentAt, {
  bool read = false,
}) => AppNotification(
  id: id,
  title: 'Unshrimp',
  body: 'Line $id',
  pack: 'default',
  sentAt: sentAt,
  read: read,
  reminderKey: key,
);

class _Setup {
  _Setup(List<AppNotification> rows, [FakeDeliveryLog? deliveryLog])
    : rows = FakeNotificationsRepository(rows: rows),
      deliveryLog = deliveryLog ?? FakeDeliveryLog();

  final FakeNotificationsRepository rows;
  final FakeDeliveryLog deliveryLog;
  final log = FakeEventLog();
  List<AppNotification>? updated;

  late final marker = ReminderOpenedMarker(
    tokens: FakeTokenStorage('t'),
    sync: NotificationSync(
      deliveryLog: deliveryLog,
      repository: rows,
      tokens: FakeTokenStorage('t'),
      notifications: FakeReminderNotifications(),
      log: log,
      now: () => _now,
    ),
    repository: rows,
    log: log,
    onUpdated: (list) => updated = list,
    now: () => _now,
  );
}

void main() {
  test('marks only the tapped reminder\'s newest row', () async {
    final s = _Setup([
      _row(1, 'd1-0', DateTime.utc(2026, 9, 28, 10)), // yesterday, same slot
      _row(2, 'd1-0', DateTime.utc(2026, 9, 29, 10)), // today, the tapped one
      _row(3, 'd1-1', DateTime.utc(2026, 9, 29, 11)), // another slot
      _row(4, null, DateTime.utc(2026, 9, 29, 12)), // an older, keyless row
    ]);

    await s.marker.markOpened('d1-0');

    expect(s.rows.markedRead, [2]);
    expect(
      s.updated!.where((n) => !n.read).map((n) => n.id),
      unorderedEquals([1, 3, 4]),
    );
  });

  test('no matching row: marks nothing, never another row', () async {
    final s = _Setup([_row(1, 'd1-1', DateTime.utc(2026, 9, 29, 10))]);

    await s.marker.markOpened('d9-0');

    expect(s.rows.markedRead, isEmpty);
    expect(s.updated, isNull);
    expect(s.log.events, contains('reminder_open_unmatched'));
  });

  test('logs the reminder first when its row did not exist yet', () async {
    final s = _Setup(
      [],
      FakeDeliveryLog(
        schedule: [
          ScheduledReminder.once(
            key: 'o5',
            at: DateTime.utc(2026, 9, 29, 14, 59),
            body: 'Boo.',
            pack: 'halloween',
            scheduledAt: DateTime.utc(2026, 9, 29, 14, 58),
          ),
        ],
      ),
    );

    await s.marker.markOpened('o5');

    expect(s.rows.logged.single.single.reminderKey, 'o5');
    expect(s.rows.markedRead, [1]);
    expect(s.updated!.single.read, isTrue);
  });

  test('an already read row is not marked again', () async {
    final s = _Setup([
      _row(1, 'd1-0', DateTime.utc(2026, 9, 29, 10), read: true),
    ]);

    await s.marker.markOpened('d1-0');

    expect(s.rows.markedRead, isEmpty);
  });
}
