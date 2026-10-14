import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/repositories/token_storage.dart';
import '../models/app_notification.dart';
import '../repositories/notifications_repository.dart';
import '../services/notification_sync.dart';

final hasUnreadNotificationsProvider =
    AsyncNotifierProvider.autoDispose<HasUnreadNotificationsViewModel, bool>(
      HasUnreadNotificationsViewModel.new,
      retry: (_, _) => null,
    );

/// Whether the user has any unread notification: the dot on Home's bell.
/// Loads from `get_notifications` after logging the reminders shown since
/// the last sync; the Notification Center keeps it in step with its list.
class HasUnreadNotificationsViewModel extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return false;
    await ref.read(notificationSyncProvider).sync();
    return _anyUnread(
      (await ref.read(notificationsRepositoryProvider).fetch(token)).value,
    );
  }

  /// Reloads without a loading state, so the dot doesn't flicker.
  Future<void> refresh() async {
    final next = await AsyncValue.guard(build);
    if (ref.mounted) state = next;
  }

  /// Takes the answer from rows already loaded (the Center's list).
  void updateFrom(List<AppNotification> notifications) =>
      state = AsyncData(_anyUnread(notifications));

  static bool _anyUnread(List<AppNotification> notifications) =>
      notifications.any((n) => !n.read);
}
