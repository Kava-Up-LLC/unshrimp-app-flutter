import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/event_log.dart';
import '../../auth/repositories/token_storage.dart';
import '../../reminders/repositories/reminder_notifications.dart';
import '../models/scheduled_reminder.dart';
import '../repositories/delivery_log.dart';
import '../repositories/notifications_repository.dart';
import 'delivered_reminders.dart';

/// Writes one `notifications` row per reminder the OS showed. The app doesn't
/// run when a reminder is shown, so each sync works out, from the recorded
/// schedule, which ones fired since the last sync and sends them in one
/// batch. Never throws: a failed sync is retried by the next one.
class NotificationSync {
  NotificationSync({
    required DeliveryLog deliveryLog,
    required NotificationsRepository repository,
    required TokenStorage tokens,
    required ReminderNotifications notifications,
    required EventLog log,
    DateTime Function()? now,
  }) : _deliveryLog = deliveryLog,
       _repository = repository,
       _tokens = tokens,
       _notifications = notifications,
       _log = log,
       _now = now ?? DateTime.now;

  final DeliveryLog _deliveryLog;
  final NotificationsRepository _repository;
  final TokenStorage _tokens;
  final ReminderNotifications _notifications;
  final EventLog _log;
  final DateTime Function() _now;

  Future<void>? _running;

  /// Sends the reminders shown since the last sync. Concurrent calls share
  /// one run, so a reminder is never sent twice by overlapping syncs.
  Future<void> sync() =>
      _running ??= _sync().whenComplete(() => _running = null);

  /// Remembers the daily reminders just handed to the OS, replacing the
  /// previous ones (call [sync] first so those are logged).
  Future<void> recordSchedule(List<ScheduledReminder> daily) async {
    final kept = (await _deliveryLog.readSchedule()).where((r) => !r.isDaily);
    await _deliveryLog.writeSchedule([...kept, ...daily]);
  }

  /// Remembers a one-off reminder (the debug one).
  Future<void> recordOnce(ScheduledReminder reminder) async {
    await _deliveryLog.writeSchedule([
      ...await _deliveryLog.readSchedule(),
      reminder,
    ]);
  }

  /// Forgets the schedule, e.g. on logout.
  Future<void> forget() => _deliveryLog.clear();

  Future<void> _sync() async {
    try {
      final token = await _tokens.read();
      if (token == null) return;

      final now = _now();
      final schedule = await _deliveryLog.readSchedule();
      final delivered = deliveredReminders(
        schedule: schedule,
        since: await _deliveryLog.readLastSync(),
        now: now,
        title: ReminderNotifications.title,
      );

      // With notifications off, nothing was shown: nothing to log.
      if (delivered.isNotEmpty && await _notifications.areEnabled()) {
        await _repository.log(token, delivered);
        _log.log('notifications_logged', {'count': '${delivered.length}'});
      }

      await _deliveryLog.writeLastSync(now);
      // One-off reminders that already fired are done.
      final pending = schedule
          .where((r) => r.isDaily || r.at!.isAfter(now))
          .toList();
      if (pending.length != schedule.length) {
        await _deliveryLog.writeSchedule(pending);
      }
    } catch (e) {
      _log.log('notifications_log_failed', {'error': e.toString()});
    }
  }
}

final notificationSyncProvider = Provider<NotificationSync>(
  (ref) => NotificationSync(
    deliveryLog: ref.read(deliveryLogProvider),
    repository: ref.read(notificationsRepositoryProvider),
    tokens: ref.read(tokenStorageProvider),
    notifications: ref.read(reminderNotificationsProvider),
    log: ref.read(eventLogProvider),
  ),
);
