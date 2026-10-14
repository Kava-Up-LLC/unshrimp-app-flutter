import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/auth/models/auth_exception.dart';
import 'package:unshrimp_app/features/notifications/services/notification_sync.dart';
import 'package:unshrimp_app/features/reminders/models/reminder_payload.dart';
import 'package:unshrimp_app/features/reminders/repositories/sarcasm_pack_repository.dart';
import 'package:unshrimp_app/features/reminders/services/reminder_scheduler.dart';
import 'package:unshrimp_app/features/settings/models/user_settings.dart';

import '../auth/fakes.dart';
import '../notifications/fakes.dart';
import '../settings/fakes.dart';
import 'fakes.dart';

final _now = DateTime.utc(2026, 9, 29, 12);

class _Setup {
  _Setup({String? token = 't', AuthException? fetchError})
    : settings = FakeSettingsRepository(fetchError: fetchError),
      tokens = FakeTokenStorage(token);

  final notifications = FakeReminderNotifications();
  final log = FakeEventLog();
  final FakeSettingsRepository settings;
  final FakeTokenStorage tokens;

  /// The clock; tests move it forward.
  DateTime now = _now;
  final deliveryLog = FakeDeliveryLog();
  final rows = FakeNotificationsRepository();

  late final sync = NotificationSync(
    deliveryLog: deliveryLog,
    repository: rows,
    tokens: tokens,
    notifications: notifications,
    log: log,
    now: () => now,
  );

  late final scheduler = ReminderScheduler(
    notifications: notifications,
    sarcasmPack: SarcasmPackRepository(
      FakeReminderPreferences(),
      readConfig: (_) async => null,
      readCms: (_) async => ['A', 'B', 'C'],
    ),
    settings: settings,
    tokens: tokens,
    sync: sync,
    log: log,
    random: Random(1),
    now: () => now,
  );
}

UserSettings _settings({DateTime? pausedUntil, bool quiet = false}) =>
    UserSettings(
      activeStart: '09:00',
      activeEnd: '12:00',
      reminderIntervalMin: 60,
      graceWindowMin: 60,
      dailyGoal: 5,
      tone: 'direct',
      painZone: 'neck',
      quietMode: quiet,
      pausedUntil: pausedUntil,
    );

void main() {
  test('cancels the old reminders first, then schedules each slot', () async {
    final s = _Setup();

    await s.scheduler.reschedule(_settings(quiet: true));

    expect(s.notifications.calls.first, isA<CancelAllCall>());
    expect(
      s.notifications.daily.map((c) => (c.id, c.hour, c.minute, c.quiet)),
      [(0, 10, 0, true), (1, 11, 0, true), (2, 12, 0, true)],
    );
    // Tapping a reminder opens the break for the user's zone, and its key
    // (one per slot) is the one recorded for its notifications rows.
    final payloads = [
      for (final c in s.notifications.daily) ReminderPayload.decode(c.payload),
    ];
    expect(payloads.map((p) => p.zone).toSet(), {'neck'});
    expect(payloads.map((p) => p.key).toSet(), hasLength(3));
    expect(
      payloads.map((p) => p.key),
      s.deliveryLog.schedule.map((r) => r.key),
    );
    // Consecutive slots get different lines.
    expect(s.notifications.daily.map((c) => c.body).toSet(), hasLength(3));
    expect(s.log.events, ['reminders_scheduled']);
    // Recorded with their text and pack for the Notification Center.
    expect(
      s.deliveryLog.schedule.map((r) => (r.hour, r.body, r.pack)),
      s.notifications.daily.map((c) => (c.hour, c.body, 'default')),
    );
  });

  test('paused: cancels and schedules nothing', () async {
    final s = _Setup();

    await s.scheduler.reschedule(
      _settings(pausedUntil: _now.add(const Duration(days: 1))),
    );

    expect(s.notifications.calls, [isA<CancelAllCall>()]);
    expect(s.deliveryLog.schedule, isEmpty);
  });

  test('rescheduleFromServer reads get_settings', () async {
    final s = _Setup();

    await s.scheduler.rescheduleFromServer();

    // testSettings: 09:00 to 18:00 every 60 min.
    expect(s.notifications.daily, hasLength(9));
  });

  test('keeps the current reminders when there is no session', () async {
    final s = _Setup(token: null);

    await s.scheduler.rescheduleFromServer();

    expect(s.notifications.calls, isEmpty);
  });

  test('keeps the current reminders when get_settings fails', () async {
    final s = _Setup(
      fetchError: const AuthException(code: 'NETWORK', message: 'offline'),
    );

    await s.scheduler.rescheduleFromServer();

    expect(s.notifications.calls, isEmpty);
    expect(s.log.events, ['reminders_schedule_failed']);
  });

  test('the debug reminder leaves the schedule alone', () async {
    final s = _Setup();

    await s.scheduler.fireTest();

    final call = s.notifications.calls.single as OnceCall;
    expect(call.id, ReminderScheduler.testReminderId);
    expect(call.delay, const Duration(seconds: 5));
    expect(['A', 'B', 'C'], contains(call.body));
    expect(s.log.events, ['reminder_test_fired']);
    final recorded = s.deliveryLog.schedule.single;
    expect(recorded.at, _now.add(const Duration(seconds: 5)));
    expect(recorded.body, call.body);
    final payload = ReminderPayload.decode(call.payload);
    expect(payload.zone, isNull);
    expect(payload.key, recorded.key);
  });

  test('enable schedules only when permission is granted', () async {
    final s = _Setup();

    expect(await s.scheduler.enable(), isTrue);
    expect(s.notifications.daily, isNotEmpty);
  });

  test('rescheduling logs what the old schedule showed first', () async {
    final s = _Setup()..now = DateTime(2026, 9, 29, 8);
    await s.scheduler.reschedule(_settings());

    s.now = DateTime(2026, 9, 29, 11, 30);
    await s.scheduler.reschedule(_settings());

    // 10:00 and 11:00 fired under the previous schedule.
    expect(s.rows.logged.single.map((r) => r.sentAt.hour), [10, 11]);
    expect(s.rows.logged.single.first.pack, 'default');
  });

  test('logout logs the shown reminders, then forgets the schedule', () async {
    final s = _Setup()..now = DateTime(2026, 9, 29, 8);
    await s.scheduler.reschedule(_settings());
    s.now = DateTime(2026, 9, 29, 10, 30);

    await s.scheduler.cancelAll();

    expect(s.rows.logged.single, isNotEmpty);
    expect(s.deliveryLog.schedule, isEmpty);
    expect(s.deliveryLog.lastSync, isNull);
  });
}
