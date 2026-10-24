import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../push/services/push_notifications.dart';
import '../models/reminder_permission_state.dart';
import '../repositories/reminder_preferences.dart';
import '../services/reminder_scheduler.dart';

final reminderPermissionViewModelProvider =
    NotifierProvider.autoDispose<
      ReminderPermissionViewModel,
      ReminderPermissionState
    >(ReminderPermissionViewModel.new);

/// First-run notification permission: asked once, whatever the answer.
class ReminderPermissionViewModel extends Notifier<ReminderPermissionState> {
  @override
  ReminderPermissionState build() => const ReminderPermissionState();

  /// Shows the OS prompt; reminders are scheduled if the user allows them, and
  /// push registers off the same grant (no second prompt).
  Future<void> allow() => _answer(() async {
    final granted = await ref.read(reminderSchedulerProvider).enable();
    // Fire-and-forget: registering the push token must not hold up leaving the
    // permission screen, and the SDK also uploads the token on start().
    if (granted) {
      unawaited(ref.read(pushNotificationsProvider).register().catchError((_) {}));
    }
  });

  Future<void> skip() => _answer(() async {});

  Future<void> _answer(Future<void> Function() action) async {
    if (state.isBusy) return;
    state = state.copyWith(isBusy: true);
    await ref.read(reminderPreferencesProvider).markPermissionAsked();
    await action();
    if (!ref.mounted) return;
    state = state.copyWith(isBusy: false, isDone: true);
  }
}
