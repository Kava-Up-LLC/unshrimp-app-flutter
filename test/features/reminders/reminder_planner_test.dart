import 'package:flutter_test/flutter_test.dart';
import 'package:move_well_app/features/reminders/models/reminder_slot.dart';
import 'package:move_well_app/features/reminders/services/reminder_planner.dart';
import 'package:move_well_app/features/settings/models/user_settings.dart';

final _now = DateTime.utc(2026, 9, 29, 12);

UserSettings _settings({
  String start = '09:00',
  String end = '18:00',
  int interval = 60,
  DateTime? pausedUntil,
}) => UserSettings(
  activeStart: start,
  activeEnd: end,
  reminderIntervalMin: interval,
  graceWindowMin: interval,
  dailyGoal: 5,
  tone: 'direct',
  painZone: 'neck',
  quietMode: false,
  pausedUntil: pausedUntil,
);

List<String> _times(UserSettings s) =>
    planReminders(s, _now).map((slot) => slot.toString()).toList();

void main() {
  test('one reminder every interval after the start, up to the end', () {
    expect(_times(_settings(interval: 90)), [
      '10:30',
      '12:00',
      '13:30',
      '15:00',
      '16:30',
      '18:00',
    ]);
  });

  test('never fires past active_end', () {
    expect(_times(_settings(end: '11:00', interval: 45)), ['09:45', '10:30']);
  });

  test('a window that crosses midnight wraps around', () {
    expect(_times(_settings(start: '22:00', end: '01:00')), [
      '23:00',
      '00:00',
      '01:00',
    ]);
  });

  test('nothing while paused_until is in the future', () {
    expect(
      planReminders(
        _settings(pausedUntil: _now.add(const Duration(hours: 1))),
        _now,
      ),
      isEmpty,
    );
  });

  test('a pause that already ended does not block reminders', () {
    expect(
      planReminders(
        _settings(pausedUntil: _now.subtract(const Duration(minutes: 1))),
        _now,
      ),
      hasLength(9),
    );
  });

  test('a full day at 30 min stays within the slot cap', () {
    final slots = planReminders(
      _settings(start: '00:00', end: '00:00', interval: 30),
      _now,
    );
    expect(slots, hasLength(maxReminderSlots));
    expect(slots.toSet(), hasLength(maxReminderSlots));
    expect(slots.first, const ReminderSlot(hour: 0, minute: 30));
  });

  test('unreadable settings plan nothing', () {
    expect(planReminders(_settings(start: ''), _now), isEmpty);
    expect(planReminders(_settings(end: '25:00'), _now), isEmpty);
    expect(planReminders(_settings(interval: 0), _now), isEmpty);
  });

  test('accepts HH:mm:ss from the server', () {
    expect(_times(_settings(start: '09:00:00', end: '11:00:00')), [
      '10:00',
      '11:00',
    ]);
  });
}
