import '../../settings/models/user_settings.dart';
import '../models/reminder_slot.dart';

/// Most reminders a day: 24 h at the shortest interval (30 min). Keeps the
/// total under iOS's 64 pending-notification limit.
const maxReminderSlots = 48;

/// Times of day to remind at: every `reminder_interval_min` after
/// `active_start`, up to and including `active_end`. A window whose end is
/// not after its start crosses midnight. Empty while paused at [now] or when
/// the settings can't be read.
List<ReminderSlot> planReminders(UserSettings settings, DateTime now) {
  if (settings.isPausedAt(now)) return const [];

  final start = _minuteOfDay(settings.activeStart);
  var end = _minuteOfDay(settings.activeEnd);
  final interval = settings.reminderIntervalMin;
  if (start == null || end == null || interval <= 0) return const [];
  if (end <= start) end += Duration.minutesPerDay;

  return [
    for (var t = start + interval; t <= end; t += interval)
      ReminderSlot.fromMinuteOfDay(t),
  ].take(maxReminderSlots).toList();
}

/// Parses `HH:mm` (seconds, if present, are ignored).
int? _minuteOfDay(String time) {
  final parts = time.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
}
