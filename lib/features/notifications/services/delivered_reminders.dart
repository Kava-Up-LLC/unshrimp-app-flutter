import '../models/delivered_reminder.dart';
import '../models/scheduled_reminder.dart';

/// Most rows sent in one `log_notifications` call (its server-side cap).
const maxDeliveredBatch = 100;

/// Reminders of [schedule] the OS showed after [since] and up to [now],
/// oldest first. Nothing counts from before a reminder was scheduled. Keeps
/// the newest [maxDeliveredBatch] when the app wasn't opened for a while.
List<DeliveredReminder> deliveredReminders({
  required List<ScheduledReminder> schedule,
  required DateTime? since,
  required DateTime now,
  required String title,
}) {
  final delivered = <DeliveredReminder>[];

  for (final reminder in schedule) {
    final from = since == null || since.isBefore(reminder.scheduledAt)
        ? reminder.scheduledAt
        : since;
    bool shown(DateTime time) => time.isAfter(from) && !time.isAfter(now);
    DeliveredReminder at(DateTime time) => DeliveredReminder(
      title: title,
      body: reminder.body,
      pack: reminder.pack,
      sentAt: time,
      reminderKey: reminder.key,
    );

    if (!reminder.isDaily) {
      if (shown(reminder.at!)) delivered.add(at(reminder.at!));
      continue;
    }

    // Daily: one firing per local day at hour:minute.
    final start = from.toLocal();
    final end = now.toLocal();
    for (
      var day = DateTime(start.year, start.month, start.day);
      !day.isAfter(end);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      final time = DateTime(
        day.year,
        day.month,
        day.day,
        reminder.hour!,
        reminder.minute!,
      );
      if (shown(time)) delivered.add(at(time));
    }
  }

  delivered.sort((a, b) => a.sentAt.compareTo(b.sentAt));
  return delivered.length > maxDeliveredBatch
      ? delivered.sublist(delivered.length - maxDeliveredBatch)
      : delivered;
}
