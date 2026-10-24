import 'dart:async';

import 'package:appambit_sdk_push_notifications/appambit_sdk_push_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/repositories/token_storage.dart';
import '../../notifications/repositories/notifications_repository.dart';
import '../../notifications/view_models/has_unread_notifications_view_model.dart';
import '../services/push_background_buffer.dart';
import 'push_providers.dart';

/// Stores every push the device receives — foreground or tapped — as a row in
/// the Notification Center, so it shows there with the bell badge and can be
/// reopened. A push seen in the foreground and then tapped records twice, but
/// `record_push` keeps a single row per push, so the Center never duplicates.
///
/// Watched by the root widget so it lives for the session; it never throws (a
/// failed store is non-fatal — the banner and navigation already happened).
final pushCenterRecorderProvider = Provider<void>((ref) {
  Future<void> store(String? title, String? body, String? open) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .recordPush(token, title: title, body: body, open: open);
      await ref.read(hasUnreadNotificationsProvider.notifier).refresh();
    } catch (_) {
      // Non-fatal: the next Center/badge read picks the row up if it stored.
    }
  }

  void record(PushNotificationData data) =>
      store(data.title, data.body, data.data?['open']);

  // On open, flush pushes the Android background handler buffered while the app
  // was closed, through the same record_push (its dedup covers overlap with a
  // later tap). No-op when nothing was buffered or signed out.
  Future<void> flushBackground() async {
    try {
      for (final p in await const PushBackgroundBuffer().drain()) {
        await store(p['title'], p['body'], p['open']);
      }
    } catch (_) {
      // Storage unavailable: nothing buffered is lost (drain only clears on read).
    }
  }

  unawaited(flushBackground());

  ref.listen(pushForegroundProvider, (_, next) {
    if (next case AsyncData(:final value)) record(value);
  });
  ref.listen(pushOpenedProvider, (_, next) {
    if (next case AsyncData(:final value)) record(value);
  });
});
