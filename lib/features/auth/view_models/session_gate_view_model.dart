import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/session/reminder_data_cleanup.dart';
import '../../break/models/break_args.dart';
import '../../reminders/repositories/reminder_notifications.dart';
import '../../reminders/services/reminder_scheduler.dart';
import '../models/session_start.dart';
import '../models/session_status.dart';
import '../repositories/auth_repository.dart';
import '../repositories/token_storage.dart';

final sessionGateViewModelProvider =
    AsyncNotifierProvider.autoDispose<SessionGateViewModel, SessionStart>(
      SessionGateViewModel.new,
    );

/// Reads the stored token and asks `auth_validate` whether it is still valid.
class SessionGateViewModel extends AsyncNotifier<SessionStart> {
  static const _loggedOut = SessionStart(SessionStatus.unauthenticated);

  @override
  Future<SessionStart> build() async {
    final storage = ref.read(tokenStorageProvider);
    final token = await storage.read();
    if (token == null) {
      // No session: a fresh install (Android backup is disabled) or a logged-out
      // device must not keep a schedule from a previous install or user. Cancel
      // and wipe before anything reschedules.
      await clearReminderData(ref);
      return _loggedOut;
    }

    try {
      final valid = await ref.read(authRepositoryProvider).validate(token);
      if (valid) {
        // App start: reprogram reminders from the current settings.
        unawaited(ref.read(reminderSchedulerProvider).rescheduleFromServer());
        return SessionStart(
          SessionStatus.authenticated,
          location: await _launchLocation(),
        );
      }
      await storage.delete();
    } on Exception {
      // Network or backend failure: fall back to Log In, keep the token.
    }
    return _loggedOut;
  }

  /// The break when a tapped reminder launched the app (cold start), else
  /// Home.
  Future<String> _launchLocation() async {
    try {
      final payload = await ref
          .read(reminderNotificationsProvider)
          .launchPayload();
      if (payload != null) {
        return BreakArgs.fromReminderPayload(payload).location;
      }
    } catch (_) {
      // Notifications unavailable: open Home as usual.
    }
    return AppRoutes.home;
  }
}
