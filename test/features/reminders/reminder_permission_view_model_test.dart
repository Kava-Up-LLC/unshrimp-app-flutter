import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_well_app/features/reminders/repositories/reminder_preferences.dart';
import 'package:move_well_app/features/reminders/services/reminder_scheduler.dart';
import 'package:move_well_app/features/reminders/view_models/reminder_permission_view_model.dart';

import 'fakes.dart';

ProviderContainer _container(
  FakeReminderScheduler scheduler,
  FakeReminderPreferences prefs,
) {
  final container = ProviderContainer(
    overrides: [
      reminderSchedulerProvider.overrideWithValue(scheduler),
      reminderPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);
  container.listen(reminderPermissionViewModelProvider, (_, _) {});
  return container;
}

void main() {
  test('allow asks the OS and remembers it was asked', () async {
    final scheduler = FakeReminderScheduler();
    final prefs = FakeReminderPreferences();
    final c = _container(scheduler, prefs);

    await c.read(reminderPermissionViewModelProvider.notifier).allow();

    expect(scheduler.enableCalls, 1);
    expect(prefs.asked, isTrue);
    expect(c.read(reminderPermissionViewModelProvider).isDone, isTrue);
  });

  test('not now skips the OS prompt but is not asked again', () async {
    final scheduler = FakeReminderScheduler();
    final prefs = FakeReminderPreferences();
    final c = _container(scheduler, prefs);

    await c.read(reminderPermissionViewModelProvider.notifier).skip();

    expect(scheduler.enableCalls, 0);
    expect(prefs.asked, isTrue);
    expect(c.read(reminderPermissionViewModelProvider).isDone, isTrue);
  });
}
