import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/push/services/push_notifications.dart';
import 'package:unshrimp_app/features/reminders/repositories/reminder_preferences.dart';
import 'package:unshrimp_app/features/reminders/services/reminder_scheduler.dart';
import 'package:unshrimp_app/features/reminders/view_models/reminder_permission_view_model.dart';

import '../push/fakes.dart';
import 'fakes.dart';

ProviderContainer _container(
  FakeReminderScheduler scheduler,
  FakeReminderPreferences prefs,
  FakePushNotifications push,
) {
  final container = ProviderContainer(
    overrides: [
      reminderSchedulerProvider.overrideWithValue(scheduler),
      reminderPreferencesProvider.overrideWithValue(prefs),
      pushNotificationsProvider.overrideWithValue(push),
    ],
  );
  addTearDown(container.dispose);
  container.listen(reminderPermissionViewModelProvider, (_, _) {});
  return container;
}

void main() {
  test('allow asks the OS, remembers it, and registers push', () async {
    final scheduler = FakeReminderScheduler();
    final prefs = FakeReminderPreferences();
    final push = FakePushNotifications();
    final c = _container(scheduler, prefs, push);

    await c.read(reminderPermissionViewModelProvider.notifier).allow();

    expect(scheduler.enableCalls, 1);
    expect(push.registerCalls, 1);
    expect(prefs.asked, isTrue);
    expect(c.read(reminderPermissionViewModelProvider).isDone, isTrue);
  });

  test('allow does not register push when permission is denied', () async {
    final scheduler = FakeReminderScheduler(grants: false);
    final prefs = FakeReminderPreferences();
    final push = FakePushNotifications();
    final c = _container(scheduler, prefs, push);

    await c.read(reminderPermissionViewModelProvider.notifier).allow();

    expect(scheduler.enableCalls, 1);
    expect(push.registerCalls, 0);
  });

  test('not now skips the OS prompt and push, but is not asked again', () async {
    final scheduler = FakeReminderScheduler();
    final prefs = FakeReminderPreferences();
    final push = FakePushNotifications();
    final c = _container(scheduler, prefs, push);

    await c.read(reminderPermissionViewModelProvider.notifier).skip();

    expect(scheduler.enableCalls, 0);
    expect(push.registerCalls, 0);
    expect(prefs.asked, isTrue);
    expect(c.read(reminderPermissionViewModelProvider).isDone, isTrue);
  });
}
