import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/models/auth_exception.dart';
import '../../auth/repositories/token_storage.dart';
import '../models/app_notification.dart';
import '../repositories/notifications_repository.dart';
import '../services/notification_sync.dart';
import 'has_unread_notifications_view_model.dart';

final notificationCenterViewModelProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationCenterViewModel,
      List<AppNotification>
    >(NotificationCenterViewModel.new, retry: (_, _) => null);

/// The user's notifications, newest first. Opening the Center first logs the
/// reminders shown since the last sync, so they're already in the list. Every
/// change is passed to [hasUnreadNotificationsProvider] so Home's dot follows.
class NotificationCenterViewModel extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    final token = await _token();
    await ref.read(notificationSyncProvider).sync();
    final notifications = await ref
        .read(notificationsRepositoryProvider)
        .fetch(token);
    _shareUnread(notifications);
    return notifications;
  }

  /// Pull to refresh: keeps the list on screen while it reloads.
  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  /// Marks [notification] read, at once on screen; reverts if the server
  /// rejects it. The view opens the break.
  Future<void> opened(AppNotification notification) async {
    if (notification.read) return;
    _setRead(notification.id, true);
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .markRead(await _token(), notification.id);
    } on AuthException {
      if (ref.mounted) _setRead(notification.id, false);
    }
  }

  void _setRead(int id, bool read) {
    final current = state.value;
    if (current == null) return;
    final updated = [
      for (final n in current) n.id == id ? n.copyWith(read: read) : n,
    ];
    state = AsyncData(updated);
    _shareUnread(updated);
  }

  void _shareUnread(List<AppNotification> notifications) => ref
      .read(hasUnreadNotificationsProvider.notifier)
      .updateFrom(notifications);

  Future<String> _token() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) {
      throw const AuthException(
        code: 'INVALID_TOKEN',
        message: 'Your session has expired. Please log in again.',
      );
    }
    return token;
  }
}
