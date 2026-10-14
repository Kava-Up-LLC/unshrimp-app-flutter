import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_status.dart';
import '../../../core/cache/cached_read.dart';
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

    // Paint the cached history instantly, then sync + revalidate in the
    // background so the list is there at once and corrects itself a moment
    // later.
    final cached = await ref
        .read(notificationsRepositoryProvider)
        .cachedNotifications(token);
    if (cached != null) {
      _shareUnread(cached);
      unawaited(_revalidate(token));
      return cached;
    }

    // Cold start with nothing cached: log the delivered reminders, then read
    // (the cache-backed read serves the stored list offline).
    await ref.read(notificationSyncProvider).sync();
    final result = await ref.read(notificationsRepositoryProvider).fetch(token);
    _shareUnread(result.value);
    _reportStatus(result);
    return result.value;
  }

  /// Syncs the delivered reminders and re-reads the history after an instant
  /// cache paint. A transport failure keeps the painted list and flags the app
  /// offline; a rejected token surfaces so the session can end.
  Future<void> _revalidate(String token) async {
    await ref.read(notificationSyncProvider).sync();
    try {
      final result = await ref.read(notificationsRepositoryProvider).fetch(token);
      if (!ref.mounted) return;
      state = AsyncData(result.value);
      _shareUnread(result.value);
      _reportStatus(result);
    } on AuthException catch (e, st) {
      if (ref.mounted) state = AsyncError(e, st);
    }
  }

  // Deferred to a microtask so it never mutates a provider during a build.
  void _reportStatus(CacheResult<List<AppNotification>> result) =>
      Future.microtask(() {
        if (ref.mounted) ref.read(cacheStatusProvider.notifier).apply(result);
      });

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

  /// The long-press "mark as read" action — the same as tapping a tile, but
  /// without opening the break.
  Future<void> markRead(AppNotification notification) => opened(notification);

  /// Marks every notification read at once; reverts if the server rejects it.
  Future<void> markAllRead() async {
    final current = state.value;
    if (current == null || current.every((n) => n.read)) return;
    final previous = current;
    final updated = [
      for (final n in current) n.read ? n : n.copyWith(read: true),
    ];
    state = AsyncData(updated);
    _shareUnread(updated);
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .markAllRead(await _token());
    } on AuthException {
      if (ref.mounted) {
        state = AsyncData(previous);
        _shareUnread(previous);
      }
    }
  }

  /// Soft-deletes one notification, removing it from the list at once; reverts
  /// if the server rejects it.
  Future<void> delete(AppNotification notification) async {
    final current = state.value;
    if (current == null) return;
    final previous = current;
    final updated = [
      for (final n in current)
        if (n.id != notification.id) n,
    ];
    state = AsyncData(updated);
    _shareUnread(updated);
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .delete(await _token(), notification.id);
    } on AuthException {
      if (ref.mounted) {
        state = AsyncData(previous);
        _shareUnread(previous);
      }
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
