import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notifications/view_models/has_unread_notifications_view_model.dart';
import '../services/reminder_scheduler.dart';

/// Reschedules when the app comes back to the foreground: logs the reminders
/// shown meanwhile and picks up a changed `sarcasm_pack`. Then refreshes
/// Home's unread dot, which those new rows may turn on. Watched by the root
/// widget so it lives as long as the app.
final reminderResumeProvider = Provider<void>((ref) {
  Future<void> onResume() async {
    await ref.read(reminderSchedulerProvider).rescheduleFromServer();
    // Only while someone shows the dot (Home is mounted, i.e. logged in).
    if (ref.exists(hasUnreadNotificationsProvider)) {
      await ref.read(hasUnreadNotificationsProvider.notifier).refresh();
    }
  }

  final listener = AppLifecycleListener(onResume: () => unawaited(onResume()));
  ref.onDispose(listener.dispose);
});
