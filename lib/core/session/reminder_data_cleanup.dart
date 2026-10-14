import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/repositories/token_storage.dart';
import '../../features/notifications/repositories/delivery_log.dart';
import '../../features/reminders/repositories/reminder_preferences.dart';
import '../../features/reminders/services/reminder_scheduler.dart';
import '../cache/cache_store.dart';
import '../cache/cache_user_id.dart';
import '../outbox/outbox_store.dart';

/// Clears every reminder artefact this device holds for the current user: the
/// OS-scheduled reminders, the delivery log, the reminder preferences, the read
/// cache and the write outbox.
///
/// Used by log out and by a no-session app launch, so a fresh install (whose
/// data Android must not restore) and the next account on the device both start
/// from nothing. Log out runs before the token is cleared, so this user's cache
/// entries are cleared by their id; a no-session launch has no token, so the
/// whole cache is cleared.
Future<void> clearReminderData(Ref ref) async {
  await ref.read(reminderSchedulerProvider).cancelAll();
  await ref.read(deliveryLogProvider).clear();
  await ref.read(reminderPreferencesProvider).clear();

  final cache = ref.read(cacheStoreProvider);
  final outbox = ref.read(outboxStoreProvider);
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) {
    await cache.clearAll();
    await outbox.clearAll();
  } else {
    final userId = cacheUserIdFromToken(token);
    await cache.clearUser(userId);
    await outbox.clearUser(userId);
  }
}
