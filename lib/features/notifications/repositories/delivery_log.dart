import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/scheduled_reminder.dart';

/// Device-local record of the reminders handed to the OS and of the last
/// time the shown ones were sent to `log_notifications`.
class DeliveryLog {
  const DeliveryLog(this._prefs);

  static const _scheduleKey = 'notifications.schedule';
  static const _lastSyncKey = 'notifications.last_sync';

  final SharedPreferencesAsync _prefs;

  Future<List<ScheduledReminder>> readSchedule() async {
    final raw = await _prefs.getString(_scheduleKey);
    if (raw == null) return const [];
    try {
      return [
        for (final item in jsonDecode(raw) as List)
          ScheduledReminder.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } on Object {
      // Unreadable record: start over rather than crash.
      return const [];
    }
  }

  Future<void> writeSchedule(List<ScheduledReminder> schedule) =>
      _prefs.setString(
        _scheduleKey,
        jsonEncode([for (final r in schedule) r.toJson()]),
      );

  Future<DateTime?> readLastSync() async =>
      DateTime.tryParse(await _prefs.getString(_lastSyncKey) ?? '');

  Future<void> writeLastSync(DateTime time) =>
      _prefs.setString(_lastSyncKey, time.toUtc().toIso8601String());

  Future<void> clear() async {
    await _prefs.remove(_scheduleKey);
    await _prefs.remove(_lastSyncKey);
  }
}

final deliveryLogProvider = Provider<DeliveryLog>(
  (ref) => DeliveryLog(SharedPreferencesAsync()),
);
