import 'dart:async';

import 'package:move_well_app/core/analytics/event_log.dart';
import 'package:move_well_app/features/reminders/repositories/reminder_notifications.dart';
import 'package:move_well_app/features/reminders/repositories/reminder_preferences.dart';
import 'package:move_well_app/features/reminders/services/reminder_scheduler.dart';
import 'package:move_well_app/features/settings/models/user_settings.dart';

/// Records what the view models ask of the scheduler.
class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({this.grants = true});

  final bool grants;
  int fromServerCalls = 0;
  int cancelCalls = 0;
  int testCalls = 0;
  int enableCalls = 0;
  final rescheduled = <UserSettings>[];

  @override
  Future<void> rescheduleFromServer() async => fromServerCalls++;

  @override
  Future<void> reschedule(UserSettings settings) async =>
      rescheduled.add(settings);

  @override
  Future<bool> enable() async {
    enableCalls++;
    return grants;
  }

  @override
  Future<void> cancelAll() async => cancelCalls++;

  @override
  Future<void> fireTest() async => testCalls++;
}

/// A notification call, in the order it was made.
sealed class NotificationCall {}

class CancelAllCall extends NotificationCall {}

class DailyCall extends NotificationCall {
  DailyCall(
    this.id,
    this.hour,
    this.minute,
    this.body,
    this.quiet,
    this.payload,
  );
  final int id;
  final int hour;
  final int minute;
  final String body;
  final bool quiet;
  final String? payload;
}

class OnceCall extends NotificationCall {
  OnceCall(this.id, this.delay, this.body, this.payload);
  final int id;
  final Duration delay;
  final String body;
  final String? payload;
}

class FakeReminderNotifications implements ReminderNotifications {
  FakeReminderNotifications({
    this.granted = true,
    this.launch,
    this.enabled = true,
  });

  final bool granted;

  /// Whether the OS shows the app's notifications.
  final bool enabled;

  /// Payload of the reminder that "launched" the app.
  final String? launch;
  final calls = <NotificationCall>[];
  final tapController = StreamController<String?>.broadcast();

  @override
  Stream<String?> get taps => tapController.stream;

  @override
  Future<String?> launchPayload() async => launch;

  List<DailyCall> get daily => calls.whereType<DailyCall>().toList();

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<bool> areEnabled() async => enabled;

  @override
  Future<void> cancelAll() async => calls.add(CancelAllCall());

  @override
  Future<void> scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String body,
    required bool quiet,
    String? payload,
  }) async => calls.add(DailyCall(id, hour, minute, body, quiet, payload));

  @override
  Future<void> scheduleOnce({
    required int id,
    required Duration delay,
    required String body,
    required bool quiet,
    String? payload,
  }) async => calls.add(OnceCall(id, delay, body, payload));
}

class FakeReminderPreferences implements ReminderPreferences {
  FakeReminderPreferences({this.asked = false, this.pack});

  bool asked;
  String? pack;

  @override
  Future<bool> wasPermissionAsked() async => asked;

  @override
  Future<void> markPermissionAsked() async => asked = true;

  @override
  Future<String?> readSarcasmPack() async => pack;

  @override
  Future<void> writeSarcasmPack(String raw) async => pack = raw;
}

class FakeEventLog implements EventLog {
  final events = <String>[];
  final properties = <Map<String, String>>[];

  @override
  void log(String event, [Map<String, String> properties = const {}]) {
    events.add(event);
    this.properties.add(properties);
  }
}
