import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_status.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/outbox/outbox.dart';
import '../../../core/session/reminder_data_cleanup.dart';
import '../../auth/models/auth_exception.dart';
import '../../auth/repositories/token_storage.dart';
import '../../reconcile/models/reconcile_outcome.dart';
import '../../reconcile/view_models/reconcile_view_model.dart';
import '../../reminders/services/reminder_scheduler.dart';
import '../../roast/view_models/roast_gate_provider.dart';
import '../models/pause_option.dart';
import '../models/settings_state.dart';
import '../models/user_settings.dart';
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
    // Single cache-backed read: offline it serves the stored row and flags the
    // app offline. No background revalidate, so nothing overwrites an edit the
    // user is making in the form.
    final result = await ref.read(settingsRepositoryProvider).fetch(token);
    _reportStatus(result);
    return SettingsState(settings: result.value);
  }

  // Deferred to a microtask so it never mutates a provider during a build.
  void _reportStatus(CacheResult<UserSettings> result) => Future.microtask(() {
    if (ref.mounted) ref.read(cacheStatusProvider.notifier).apply(result);
  });

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

  /// Saves which weekdays the user works (Mon first). Rescheduling (in [_update])
  /// then drops reminders on the new rest days.
  Future<void> workDaysChanged(List<bool> days) =>
      _update({'active_days': days.map((worked) => worked ? '1' : '0').join()});

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

  /// Debug only: run reconciliation treating every pending reminder as expired.
  Future<ReconcileOutcome> reconcileNowDebug() =>
      ref.read(reconcileViewModelProvider).run(forceAll: true);

  /// Debug only: re-queue the last applied operation under its original id and
  /// flush, so the server's `applied_ops` can be seen refusing to move the
  /// stats row. Goes through the real queue, not a direct call.
  Future<void> replayLastOp() => ref.read(outboxProvider.notifier).replayLast();

  /// Cancels the reminders and clears the stored session. The view navigates
  /// back to Log In.
  Future<void> logOut() async {
    ref.read(roastGateProvider.notifier).reset();
    // Clear the schedule, delivery log, reminder preferences, cache and the
    // write outbox, not just the OS reminders, so the next account on the
    // device starts from nothing.
    await clearReminderData(ref);
    await ref.read(tokenStorageProvider).delete();
    ref.invalidate(outboxProvider);
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
