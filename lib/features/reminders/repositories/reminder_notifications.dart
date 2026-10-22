import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper over `flutter_local_notifications`: the device's local
/// reminders. Initializes itself (plugin and local time zone) on first use.
class ReminderNotifications {
  ReminderNotifications(this._plugin);

  /// Title of every reminder.
  static const title = 'Unshrimp';

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<String?>.broadcast();
  Future<void>? _ready;

  /// Payloads of reminders tapped while the app is running (foreground or
  /// background). Listening sets the plugin up.
  Stream<String?> get taps {
    unawaited(_init());
    return _taps.stream;
  }

  /// Payload of the reminder whose tap launched the app, or null when the app
  /// wasn't launched from a reminder.
  Future<String?> launchPayload() async {
    await _init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload ?? '';
  }

  /// Shows the OS prompt. Returns whether notifications are allowed.
  Future<bool> requestPermission() async {
    await _init();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// Whether the OS shows this app's notifications.
  Future<bool> areEnabled() async {
    await _init();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return (await ios.checkPermissions())?.isEnabled ?? false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.areNotificationsEnabled() ?? false;
  }

  /// Removes every scheduled and delivered reminder.
  Future<void> cancelAll() async {
    await _init();
    await _plugin.cancelAll();
  }

  /// Fires every day at [hour]:[minute] local time.
  Future<void> scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String body,
    required bool quiet,
    String? payload,
  }) async {
    await _init();
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _schedule(
      id: id,
      at: at,
      body: body,
      quiet: quiet,
      payload: payload,
      repeat: DateTimeComponents.time,
    );
  }

  /// Fires every week on [weekday] (DateTime.weekday: 1 = Mon .. 7 = Sun) at
  /// [hour]:[minute] local time. Used when the user has rest days, so reminders
  /// land only on the weekdays they work.
  Future<void> scheduleWeekly({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
    required String body,
    required bool quiet,
    String? payload,
  }) async {
    await _init();
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (at.weekday != weekday || !at.isAfter(now)) {
      at = at.add(const Duration(days: 1));
    }
    await _schedule(
      id: id,
      at: at,
      body: body,
      quiet: quiet,
      payload: payload,
      repeat: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Fires once, [delay] from now.
  Future<void> scheduleOnce({
    required int id,
    required Duration delay,
    required String body,
    required bool quiet,
    String? payload,
  }) async {
    await _init();
    await _schedule(
      id: id,
      at: tz.TZDateTime.now(tz.local).add(delay),
      body: body,
      quiet: quiet,
      payload: payload,
    );
  }

  Future<void> _schedule({
    required int id,
    required tz.TZDateTime at,
    required String body,
    required bool quiet,
    String? payload,
    DateTimeComponents? repeat,
  }) => _plugin.zonedSchedule(
    id: id,
    scheduledDate: at,
    title: title,
    body: body,
    payload: payload,
    notificationDetails: _details(quiet: quiet),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents: repeat,
  );

  Future<void> _init() => _ready ??= _initialize();

  Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Unknown zone id: keep the default (UTC).
    }
    await _plugin.initialize(
      onDidReceiveNotificationResponse: (response) =>
          _taps.add(response.payload),
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        // The permission screen asks; don't prompt on initialize.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  static NotificationDetails _details({required bool quiet}) =>
      NotificationDetails(
        android: quiet
            ? const AndroidNotificationDetails(
                'reminders_quiet',
                'Quiet reminders',
                channelDescription: 'Posture reminders without sound.',
                importance: Importance.low,
                priority: Priority.low,
                playSound: false,
                enableVibration: false,
              )
            : const AndroidNotificationDetails(
                'reminders',
                'Reminders',
                channelDescription:
                    'Posture reminders during your active hours.',
                importance: Importance.high,
                priority: Priority.high,
              ),
        iOS: DarwinNotificationDetails(presentSound: !quiet),
      );
}

final reminderNotificationsProvider = Provider<ReminderNotifications>(
  (ref) => ReminderNotifications(FlutterLocalNotificationsPlugin()),
);
