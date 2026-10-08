import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/reminder_data_cleanup.dart';
import '../../auth/models/auth_exception.dart';
import '../../auth/repositories/token_storage.dart';
import '../../home/repositories/home_repository.dart';
import '../../home/view_models/home_view_model.dart';
import '../../reconcile/models/reconcile_outcome.dart';
import '../../reconcile/view_models/reconcile_view_model.dart';
import '../../reminders/services/reminder_scheduler.dart';
import '../models/pause_option.dart';
import '../models/settings_state.dart';
import '../repositories/settings_repository.dart';

final settingsViewModelProvider =
    AsyncNotifierProvider.autoDispose<SettingsViewModel, SettingsState>(
      SettingsViewModel.new,
      // Same as Home: show the error instead of retrying an expired token.
      retry: (_, _) => null,
    );

/// Loads the user's `user_settings` row and sends each change to
/// `update_settings`, showing the row the server returns.
class SettingsViewModel extends AsyncNotifier<SettingsState> {
  @override
  Future<SettingsState> build() async {
    final token = await _token();
    final settings = await ref.read(settingsRepositoryProvider).fetch(token);
    return SettingsState(settings: settings);
  }

  /// Reloads the row, showing the spinner while the call is in flight.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }

  Future<void> activeHoursChanged({
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
  }) => _update({
    'active_start': _formatTime(startHour, startMinute),
    'active_end': _formatTime(endHour, endMinute),
  });

  Future<void> reminderIntervalChanged(int minutes) =>
      _update({'reminder_interval_min': minutes});

  Future<void> dailyGoalChanged(int goal) => _update({'daily_goal': goal});

  /// Sends the tone; the server recomputes `roast_threshold` from it.
  Future<void> toneChanged(String tone) => _update({'tone': tone});

  Future<void> quietModeChanged(bool enabled) =>
      _update({'quiet_mode': enabled});

  Future<void> pause(PauseOption option) => _update({
    'paused_until': DateTime.now()
        .add(option.duration)
        .toUtc()
        .toIso8601String(),
  });

  Future<void> resume() => _update({'paused_until': null});

  /// Debug only: a reminder in a few seconds, leaving the schedule as is.
  Future<void> fireTestReminder() =>
      ref.read(reminderSchedulerProvider).fireTest();

  /// Debug only: report one ignored reminder (`register_ignore`, count 1) and
  /// push the returned row into Home. Sends the device's UTC offset so the
  /// server tests the active window against the user's wall clock.
  Future<ReconcileOutcome> registerIgnoreDebug() async {
    final result = await ref
        .read(homeRepositoryProvider)
        .registerIgnore(
          await _token(),
          count: 1,
          tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
        );
    if (ref.exists(homeViewModelProvider)) {
      ref.read(homeViewModelProvider.notifier).applyStats(result.stats);
    }
    if (result.ignored == 0) return const ReconcileOutcome.notCounted();
    return ReconcileOutcome.counted(
      ignored: result.ignored,
      batteryPercent: result.stats.batteryPercent,
    );
  }

  /// Debug only: run reconciliation treating every pending reminder as expired.
  Future<ReconcileOutcome> reconcileNowDebug() =>
      ref.read(reconcileViewModelProvider).run(forceAll: true);

  /// Cancels the reminders and clears the stored session. The view navigates
  /// back to Log In.
  Future<void> logOut() async {
    // Clear the schedule, delivery log and reminder preferences, not just the
    // OS reminders, so the next account on the device starts from nothing.
    await clearReminderData(ref);
    await ref.read(tokenStorageProvider).delete();
  }

  Future<void> _update(Map<String, Object?> changes) async {
    final current = state.value;
    if (current == null || current.isSaving) return;

    state = AsyncData(current.copyWith(isSaving: true, error: () => null));
    try {
      final settings = await ref
          .read(settingsRepositoryProvider)
          .update(await _token(), changes);
      unawaited(ref.read(reminderSchedulerProvider).reschedule(settings));
      if (!ref.mounted) return;
      state = AsyncData(SettingsState(settings: settings));
    } on AuthException catch (e) {
      if (!ref.mounted) return;
      state = AsyncData(current.copyWith(error: () => e));
    }
  }

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

  static String _formatTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
