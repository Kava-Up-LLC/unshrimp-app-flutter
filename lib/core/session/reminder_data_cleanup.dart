import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notifications/repositories/delivery_log.dart';
import '../../features/reminders/repositories/reminder_preferences.dart';
import '../../features/reminders/services/reminder_scheduler.dart';

/// Clears every reminder artefact this device holds for the current user: the
/// OS-scheduled reminders, the delivery log and the reminder preferences.
///
/// Used by log out and by a no-session app launch, so a fresh install (whose
/// data Android must not restore) and the next account on the device both start
/// from nothing. Episode 5's read cache and write outbox get cleared here too
/// once they exist.
Future<void> clearReminderData(Ref ref) async {
  await ref.read(reminderSchedulerProvider).cancelAll();
  await ref.read(deliveryLogProvider).clear();
  await ref.read(reminderPreferencesProvider).clear();
}
