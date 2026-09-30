import 'package:flutter_test/flutter_test.dart';
import 'package:move_well_app/features/notifications/models/scheduled_reminder.dart';
import 'package:move_well_app/features/notifications/services/delivered_reminders.dart';

final _scheduledAt = DateTime(2026, 9, 29, 8);

ScheduledReminder _daily(int hour, [String body = 'Sit up.']) =>
    ScheduledReminder.daily(
      key: 'k-daily',
      hour: hour,
      minute: 0,
      body: body,
      pack: 'default',
      scheduledAt: _scheduledAt,
    );

List<String> _shown(
  List<ScheduledReminder> schedule, {
  DateTime? since,
  required DateTime now,
}) => [
  for (final r in deliveredReminders(
    schedule: schedule,
    since: since,
    now: now,
    title: 'MoveWell',
  ))
    '${r.sentAt.day} ${r.sentAt.hour}:00 ${r.body}',
];

void main() {
  test('daily reminders fired since they were scheduled, oldest first', () {
    expect(
      _shown([
        _daily(11, 'B'),
        _daily(10, 'A'),
        _daily(12, 'C'),
      ], now: DateTime(2026, 9, 29, 11, 30)),
      ['29 10:00 A', '29 11:00 B'],
    );
  });

  test('only what fired after the last sync', () {
    expect(
      _shown(
        [_daily(10), _daily(11)],
        since: DateTime(2026, 9, 29, 10, 30),
        now: DateTime(2026, 9, 29, 12),
      ),
      ['29 11:00 Sit up.'],
    );
  });

  test('once a day, across days', () {
    expect(_shown([_daily(9)], now: DateTime(2026, 10, 1, 10)), [
      '29 9:00 Sit up.',
      '30 9:00 Sit up.',
      '1 9:00 Sit up.',
    ]);
  });

  test('nothing from before a reminder was scheduled', () {
    expect(
      _shown(
        [_daily(7)],
        since: DateTime(2026, 9, 28),
        now: DateTime(2026, 9, 29, 9),
      ),
      isEmpty,
    );
  });

  test('a one-off reminder counts once, when its time has come', () {
    final once = ScheduledReminder.once(
      key: 'k-once',
      at: DateTime(2026, 9, 29, 8, 0, 5),
      body: 'Boo.',
      pack: 'halloween',
      scheduledAt: _scheduledAt,
    );

    expect(_shown([once], now: DateTime(2026, 9, 29, 8, 0, 3)), isEmpty);
    final shown = deliveredReminders(
      schedule: [once],
      since: null,
      now: DateTime(2026, 9, 29, 8, 1),
      title: 'MoveWell',
    ).single;
    expect(shown.pack, 'halloween');
    expect(shown.sentAt, once.at);
  });

  test('a long absence keeps the newest rows only', () {
    final shown = deliveredReminders(
      schedule: [for (var h = 9; h <= 18; h++) _daily(h)],
      since: null,
      now: DateTime(2026, 10, 29),
      title: 'MoveWell',
    );
    expect(shown, hasLength(maxDeliveredBatch));
    expect(shown.last.sentAt, DateTime(2026, 10, 28, 18));
  });
}
