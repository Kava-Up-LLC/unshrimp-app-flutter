import 'dart:async';

import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cached_read.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/session/reminder_data_cleanup.dart';
import '../../break/models/break_args.dart';
import '../models/auth_exception.dart';
import '../../push/models/push_open.dart';
import '../../push/view_models/push_providers.dart';
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

    final expiresAt = await storage.readExpiresAt();
    final now = DateTime.now();

    // Convenience gate (NOT a security check — the device cannot verify the
    // signature; Cloud Code authorizes every data call): a stored expiry we know
    // has passed means Log In. Clear the pair.
    if (expiresAt != null && !expiresAt.isAfter(now)) {
      await storage.delete();
      return _loggedOut;
    }

    // Offline-first. A token with a future local expiry opens the app straight
    // away — no auth_validate on the critical path, so a cold or offline start
    // still lands on Home. A legacy token with no stored expiry is confirmed
    // online once, so a revoked old token still logs out; only INVALID_TOKEN
    // ends the session, a transport failure is forgiven and the app opens.
    if (expiresAt == null) {
      try {
        final valid = await ref.read(authRepositoryProvider).validate(token);
        if (!valid) {
          await storage.delete();
          return _loggedOut;
        }
      } on AuthException catch (e, st) {
        if (e.code == 'INVALID_TOKEN') {
          await storage.delete();
          return _loggedOut;
        }
        // Transport failure (offline) is forgiven silently — the app opens on
        // the cached session. A non-transport failure here is genuinely
        // unexpected, so record it (still opening the app) instead of hiding it.
        if (!isTransportError(e.code)) {
          unawaited(
            AppAmbitSdk.logError(
              message: 'session gate: unexpected validate failure (${e.code})',
              exception: e,
              stackTrace: st,
            ),
          );
        }
      }
    }

    // App start: reprogram reminders from the current settings.
    unawaited(ref.read(reminderSchedulerProvider).rescheduleFromServer());
    return SessionStart(
      SessionStatus.authenticated,
      location: await _launchLocation(),
    );
  }

  /// Where a cold-start tap launched the app: the push's screen when a push
  /// launched it (its `open` key), the break when a reminder did, else Home.
  /// Routing it here (not in a separate listener) makes it the single startup
  /// navigation, so it is never overridden by a fall-through to Home.
  Future<String> _launchLocation() async {
    final launchPush = ref.read(pushBridgeProvider)?.launchOpen;
    if (launchPush != null) {
      return pushOpenLocation(launchPush.data?['open']);
    }
    try {
      final payload = await ref
          .read(reminderNotificationsProvider)
          .launchPayload();
      if (payload != null) {
        return reminderTapLocation(payload);
      }
    } catch (_) {
      // Notifications unavailable: open Home as usual.
    }
    return AppRoutes.home;
  }
}
