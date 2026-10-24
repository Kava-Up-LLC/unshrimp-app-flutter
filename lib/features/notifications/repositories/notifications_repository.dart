import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_store.dart';
import '../../../core/cache/cache_user_id.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/cloud/cloud_functions.dart';
import '../models/app_notification.dart';
import '../models/delivered_reminder.dart';

/// Reads and writes the user's `notifications` rows through Cloud Code. The
/// database is never touched directly from the app.
///
/// The history read ([fetch]) goes through a per-user cache, so it returns the
/// last stored list offline instead of throwing; the writes are never cached.
class NotificationsRepository {
  const NotificationsRepository({
    CloudFunctions cloud = const CloudFunctions(),
    required CacheStore cache,
  }) : _cloud = cloud,
       _cache = cache;

  static const _slot = 'notifications';

  final CloudFunctions _cloud;
  final CacheStore _cache;

  Future<void> log(String token, List<DeliveredReminder> reminders) =>
      _cloud.call('log_notifications', {
        'token': token,
        'notifications': [for (final r in reminders) r.toJson()],
      });

  /// Stores a received push as a Center row (`kind=push`). Safe to call for the
  /// same push twice (foreground then tap): `record_push` keeps one row per
  /// push, so the Center never shows a duplicate.
  Future<void> recordPush(
    String token, {
    String? title,
    String? body,
    String? open,
  }) => _cloud.call('record_push', {
    'token': token,
    'title': title,
    'body': body,
    'open': open,
  });

  /// The user's notifications, newest first, cached per user. On a transport
  /// failure the stored list is returned with [CacheResult.offline] set; a
  /// function-level error (INVALID_TOKEN, …) still throws.
  Future<CacheResult<List<AppNotification>>> fetch(String token) =>
      CachedRead<List<AppNotification>>(store: _cache, decode: _decode).read(
        userId: cacheUserIdFromToken(token),
        slot: _slot,
        fetch: () => _cloud.call('get_notifications', {'token': token}),
      );

  /// The last cached notifications for this token's user, or null when none is
  /// stored. Reads nothing over the network — used to paint the Center
  /// instantly before [fetch] revalidates.
  Future<List<AppNotification>?> cachedNotifications(String token) async {
    final entry = await _cache.read(cacheUserIdFromToken(token), _slot);
    return entry == null ? null : _decode(entry.payload);
  }

  static List<AppNotification> _decode(Map<String, dynamic> data) {
    final rows = data['notifications'];
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map)
          AppNotification.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<void> markRead(String token, int id) =>
      _cloud.call('mark_notification_read', {'token': token, 'id': id});

  Future<void> markAllRead(String token) =>
      _cloud.call('mark_all_notifications_read', {'token': token});

  /// Soft-deletes one row (sets `hidden_at`) so it leaves the list but stays
  /// visible to `get_pending_reminders` — a hard delete could silently cancel
  /// an un-reconciled ignore the user still owes.
  Future<void> delete(String token, int id) =>
      _cloud.call('delete_notification', {'token': token, 'id': id});
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(cache: ref.read(cacheStoreProvider)),
);
