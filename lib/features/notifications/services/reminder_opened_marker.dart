import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/event_log.dart';
import '../../auth/repositories/token_storage.dart';
import '../models/app_notification.dart';
import '../repositories/notifications_repository.dart';
import '../view_models/has_unread_notifications_view_model.dart';
import 'notification_sync.dart';

/// Marks read the row of a reminder opened from the OS (tray, lock screen,
/// banner). Syncs first, since the row may not be logged yet, then marks the
/// newest row with the reminder's key. No match: does nothing. Never marks
/// another row and never throws.
class ReminderOpenedMarker {
  ReminderOpenedMarker({
    required TokenStorage tokens,
    required NotificationSync sync,
    required NotificationsRepository repository,
    required EventLog log,
    required void Function(List<AppNotification>) onUpdated,
    DateTime Function()? now,
  }) : _tokens = tokens,
       _sync = sync,
       _repository = repository,
       _log = log,
       _onUpdated = onUpdated,
       _now = now ?? DateTime.now;

  final TokenStorage _tokens;
  final NotificationSync _sync;
  final NotificationsRepository _repository;
  final EventLog _log;
  final void Function(List<AppNotification>) _onUpdated;
  final DateTime Function() _now;

  Future<void> markOpened(String reminderKey) async {
    try {
      final token = await _tokens.read();
      if (token == null) return;

      await _sync.sync();
      final notifications = await _repository.fetch(token);

      // A daily reminder has one row per day: the tap is on the latest one.
      final now = _now();
      AppNotification? row;
      for (final n in notifications) {
        if (n.reminderKey != reminderKey || n.sentAt.isAfter(now)) continue;
        if (row == null || n.sentAt.isAfter(row.sentAt)) row = n;
      }
      if (row == null) {
        _log.log('reminder_open_unmatched');
        return;
      }

      if (!row.read) await _repository.markRead(token, row.id);
      final id = row.id;
      _onUpdated([
        for (final n in notifications) n.id == id ? n.copyWith(read: true) : n,
      ]);
    } catch (e) {
      _log.log('reminder_open_mark_failed', {'error': e.toString()});
    }
  }
}

final reminderOpenedMarkerProvider = Provider<ReminderOpenedMarker>(
  (ref) => ReminderOpenedMarker(
    tokens: ref.read(tokenStorageProvider),
    sync: ref.read(notificationSyncProvider),
    repository: ref.read(notificationsRepositoryProvider),
    log: ref.read(eventLogProvider),
    // Home's dot follows, if Home is showing it.
    onUpdated: (notifications) {
      if (ref.exists(hasUnreadNotificationsProvider)) {
        ref
            .read(hasUnreadNotificationsProvider.notifier)
            .updateFrom(notifications);
      }
    },
  ),
);
