import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// Shows the OS prompt; reminders are scheduled if the user allows them.
  Future<void> allow() =>
      _answer(() => ref.read(reminderSchedulerProvider).enable());

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
