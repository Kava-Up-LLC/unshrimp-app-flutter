import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/models/auth_exception.dart';
import '../models/app_notification.dart';
import '../models/delivered_reminder.dart';

/// Reads and writes the user's `notifications` rows through Cloud Code. The
/// database is never touched directly from the app.
class NotificationsRepository {
  const NotificationsRepository();

  static const _timeout = Duration(seconds: 20);

  Future<void> log(String token, List<DeliveredReminder> reminders) =>
      _call('log_notifications', {
        'token': token,
        'notifications': [for (final r in reminders) r.toJson()],
      });

  /// The user's notifications, newest first.
  Future<List<AppNotification>> fetch(String token) async {
    final data = await _call('get_notifications', {'token': token});
    final rows = data['notifications'];
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map)
          AppNotification.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<void> markRead(String token, int id) =>
      _call('mark_notification_read', {'token': token, 'id': id});

  Future<Map<String, dynamic>> _call(
    String function,
    Map<String, Object?> body,
  ) async {
    try {
      final response = await CloudCode.call(
        function,
        body: body,
        timeout: _timeout,
      ).future;

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const AuthException(
          code: 'UNEXPECTED_RESPONSE',
          message: 'Unexpected response from the server.',
        );
      }

      final code = data['error'];
      if (code != null) {
        throw AuthException(
          code: code.toString(),
          message: (data['message'] ?? code).toString(),
        );
      }
      return data;
    } on CloudCodeError catch (e) {
      throw AuthException(
        code: e.code.name,
        message: e.code == CloudCodeErrorCode.http
            ? 'Something went wrong. Please try again.'
            : "Couldn't reach the server. Check your connection and try again.",
      );
    }
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => const NotificationsRepository(),
);
