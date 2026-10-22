import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/settings/models/user_settings.dart';

UserSettings _fromActiveDays(Object? activeDays) => UserSettings.fromJson({
  'active_start': '09:00',
  'active_end': '18:00',
  'reminder_interval_min': 60,
  'grace_window_min': 60,
  'daily_goal': 4,
  'tone': 'direct',
  'pain_zone': 'neck',
  'quiet_mode': false,
  'paused_until': null,
  'active_days': activeDays,
});

void main() {
  test('parses a 0/1 Mon..Sun mask, Monday first', () {
    final s = _fromActiveDays('1111110'); // Sunday off
    expect(s.workDays, [true, true, true, true, true, true, false]);
    expect(s.workDaysMask, '1111110');
    expect(s.everyDayWorked, isFalse);
  });

  test('isWorkWeekday maps DateTime.weekday (1=Mon..7=Sun)', () {
    final s = _fromActiveDays('1111110'); // Sunday (7) off
    expect(s.isWorkWeekday(DateTime.monday), isTrue);
    expect(s.isWorkWeekday(DateTime.saturday), isTrue);
    expect(s.isWorkWeekday(DateTime.sunday), isFalse);
  });

  test('a missing or malformed mask means every day is worked', () {
    for (final bad in [null, '', '123', '11111110']) {
      final s = _fromActiveDays(bad);
      expect(s.workDays, List.filled(7, true), reason: 'for $bad');
      expect(s.everyDayWorked, isTrue);
    }
  });
}
