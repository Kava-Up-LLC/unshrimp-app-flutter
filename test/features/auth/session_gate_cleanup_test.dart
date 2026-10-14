import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/auth/models/session_status.dart';
import 'package:unshrimp_app/features/auth/repositories/token_storage.dart';
import 'package:unshrimp_app/features/auth/view_models/session_gate_view_model.dart';
import 'package:unshrimp_app/features/notifications/models/scheduled_reminder.dart';
import 'package:unshrimp_app/features/notifications/repositories/delivery_log.dart';
import 'package:unshrimp_app/features/reminders/repositories/reminder_preferences.dart';
import 'package:unshrimp_app/features/reminders/services/reminder_scheduler.dart';

import 'fakes.dart';
import '../notifications/fakes.dart';
import '../reminders/fakes.dart';
import '../../support/in_memory_prefs.dart';

void main() {
  setUp(useInMemoryPrefs);

  test(
    'a launch with no token cancels reminders and wipes the schedule (zero pending)',
    () async {
      final scheduler = FakeReminderScheduler();
      final deliveryLog = FakeDeliveryLog(
        schedule: [
          ScheduledReminder.once(
            key: 'leftover',
            at: DateTime.now().add(const Duration(minutes: 30)),
            body: 'From a previous install.',
            pack: 'default',
            scheduledAt: DateTime.now(),
          ),
        ],
      );
      final prefs = FakeReminderPreferences();

      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(FakeTokenStorage(null)),
          reminderSchedulerProvider.overrideWithValue(scheduler),
          deliveryLogProvider.overrideWithValue(deliveryLog),
          reminderPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final start = await container.read(sessionGateViewModelProvider.future);

      expect(start.status, SessionStatus.unauthenticated);
      // Reminders were cancelled and never rescheduled -> zero pending.
      expect(scheduler.cancelCalls, 1);
      expect(scheduler.fromServerCalls, 0);
      // Nothing from the previous install/user is left on the device.
      expect(deliveryLog.schedule, isEmpty);
      expect(prefs.cleared, isTrue);
    },
  );
}
