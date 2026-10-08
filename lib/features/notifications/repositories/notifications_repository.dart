import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cloud/cloud_functions.dart';
import '../models/app_notification.dart';
import '../models/delivered_reminder.dart';

/// Reads and writes the user's `notifications` rows through Cloud Code. The
/// database is never touched directly from the app.
class NotificationsRepository {
  const NotificationsRepository([this._cloud = const CloudFunctions()]);

  final CloudFunctions _cloud;

  Future<void> log(String token, List<DeliveredReminder> reminders) =>
      _cloud.call('log_notifications', {
        'token': token,
        'notifications': [for (final r in reminders) r.toJson()],
      });

  /// The user's notifications, newest first.
  Future<List<AppNotification>> fetch(String token) async {
    final data = await _cloud.call('get_notifications', {'token': token});
    final rows = data['notifications'];
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map)
          AppNotification.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<void> markRead(String token, int id) =>
      _cloud.call('mark_notification_read', {'token': token, 'id': id});
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => const NotificationsRepository(),
);
