import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/repositories/token_storage.dart';
import '../../notifications/models/scheduled_reminder.dart';
import '../../notifications/services/notification_sync.dart';
import '../../settings/models/user_settings.dart';
import '../../settings/repositories/settings_repository.dart';
import '../../../core/analytics/event_log.dart';
import '../models/reminder_payload.dart';
import '../repositories/reminder_notifications.dart';
import '../repositories/sarcasm_pack_repository.dart';
import 'reminder_planner.dart';

/// The one path that turns the user's settings into local notifications.
/// Every call cancels the previous reminders before scheduling new ones, and
/// records what it scheduled so the shown ones reach the Notification Center.
/// Failures are logged, never thrown: reminders must not break login or
/// saving settings.
class ReminderScheduler {
  ReminderScheduler({
    required ReminderNotifications notifications,
    required SarcasmPackRepository sarcasmPack,
    required SettingsRepository settings,
    required TokenStorage tokens,
    required NotificationSync sync,
    required EventLog log,
    Random? random,
    DateTime Function()? now,
  }) : _notifications = notifications,
       _sarcasmPack = sarcasmPack,
       _settings = settings,
       _tokens = tokens,
       _sync = sync,
       _log = log,
       _random = random ?? Random(),
       _now = now ?? DateTime.now;

  /// Id of the debug reminder; daily slots use 0..[maxReminderSlots] - 1.
  static const testReminderId = 9999;
  static const testReminderDelay = Duration(seconds: 5);

  final ReminderNotifications _notifications;
  final SarcasmPackRepository _sarcasmPack;
  final SettingsRepository _settings;
  final TokenStorage _tokens;
  final NotificationSync _sync;
  final EventLog _log;
  final Random _random;
  final DateTime Function() _now;

  /// Reads the settings with `get_settings` and reschedules from them. On
  /// app start and after login or onboarding. Without a session, or if the
  /// settings can't be read, the current reminders are left as they are.
  Future<void> rescheduleFromServer() async {
    try {
      final token = await _tokens.read();
      if (token == null) return;
      await _reschedule(await _settings.fetch(token));
    } catch (e) {
      _log.log('reminders_schedule_failed', {'error': e.toString()});
    }
  }

  /// Reschedules from [settings] already returned by the server, e.g. by
  /// `update_settings`.
  Future<void> reschedule(UserSettings settings) async {
    try {
      await _reschedule(settings);
    } catch (e) {
      _log.log('reminders_schedule_failed', {'error': e.toString()});
    }
  }

  /// Shows the OS permission prompt and, if allowed, reschedules.
  Future<bool> enable() async {
    try {
      final granted = await _notifications.requestPermission();
      _log.log('reminders_permission', {'granted': '$granted'});
      if (granted) await rescheduleFromServer();
      return granted;
    } catch (e) {
      _log.log('reminders_permission_failed', {'error': e.toString()});
      return false;
    }
  }

  /// Removes every reminder, e.g. on logout. Logs the ones already shown
  /// first, while the session still exists.
  Future<void> cancelAll() async {
    try {
      await _sync.sync();
      await _notifications.cancelAll();
      await _sync.forget();
      _log.log('reminders_cancelled');
    } catch (e) {
      _log.log('reminders_cancel_failed', {'error': e.toString()});
    }
  }

  /// Debug only: one reminder [testReminderDelay] from now, with its own id,
  /// so the user's daily schedule stays untouched.
  Future<void> fireTest() async {
    try {
      final pack = await _sarcasmPack.loadPack();
      final body = pack.lines[_random.nextInt(pack.lines.length)];
      final now = _now();
      final at = now.add(testReminderDelay);
      final key = 'o${at.microsecondsSinceEpoch}';
      await _notifications.scheduleOnce(
        id: testReminderId,
        delay: testReminderDelay,
        body: body,
        quiet: false,
        // No zone: the break reads it from get_settings.
        payload: ReminderPayload(key: key).encode(),
      );
      await _sync.recordOnce(
        ScheduledReminder.once(
          key: key,
          at: at,
          body: body,
          pack: pack.active,
          scheduledAt: now,
        ),
      );
      _log.log('reminder_test_fired', {
        'delay_s': '${testReminderDelay.inSeconds}',
      });
    } catch (e) {
      _log.log('reminder_test_failed', {'error': e.toString()});
    }
  }

  Future<void> _reschedule(UserSettings settings) async {
    final now = _now();
    final slots = planReminders(settings, now);
    final pack = slots.isEmpty ? null : await _sarcasmPack.loadPack();

    // Log what the old schedule already showed before replacing it.
    await _sync.sync();
    await _notifications.cancelAll();

    // Consecutive slots get consecutive lines, from a random starting point.
    final lines = pack?.lines ?? const <String>[];
    final offset = lines.isEmpty ? 0 : _random.nextInt(lines.length);
    final scheduled = <ScheduledReminder>[];
    for (final (i, slot) in slots.indexed) {
      final body = lines[(offset + i) % lines.length];
      final key = 'd${now.microsecondsSinceEpoch}-$i';
      await _notifications.scheduleDaily(
        id: i,
        hour: slot.hour,
        minute: slot.minute,
        body: body,
        quiet: settings.quietMode,
        // Tapping opens the break for this zone and marks this reminder's row.
        payload: ReminderPayload(zone: settings.painZone, key: key).encode(),
      );
      scheduled.add(
        ScheduledReminder.daily(
          key: key,
          hour: slot.hour,
          minute: slot.minute,
          body: body,
          pack: pack!.active,
          scheduledAt: now,
        ),
      );
    }
    await _sync.recordSchedule(scheduled);

    _log.log('reminders_scheduled', {
      'count': '${slots.length}',
      'interval_min': '${settings.reminderIntervalMin}',
      'paused': '${settings.isPausedAt(_now())}',
      'quiet': '${settings.quietMode}',
      'pack': pack?.active ?? '',
    });
  }
}

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => ReminderScheduler(
    notifications: ref.read(reminderNotificationsProvider),
    sarcasmPack: ref.read(sarcasmPackRepositoryProvider),
    settings: ref.read(settingsRepositoryProvider),
    tokens: ref.read(tokenStorageProvider),
    sync: ref.read(notificationSyncProvider),
    log: ref.read(eventLogProvider),
  ),
);
