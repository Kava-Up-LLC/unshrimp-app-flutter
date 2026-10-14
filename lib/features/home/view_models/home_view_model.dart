import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/models/auth_exception.dart';
import '../../auth/repositories/token_storage.dart';
import '../../../core/cache/cache_status.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/outbox/outbox.dart';
import '../../../core/session/reminder_data_cleanup.dart';
import '../../roast/view_models/roast_gate_provider.dart';
import '../models/user_stats.dart';
import '../repositories/home_repository.dart';

final homeViewModelProvider =
    AsyncNotifierProvider.autoDispose<HomeViewModel, UserStats>(
      HomeViewModel.new,
      // Riverpod retries a failed build by default, which would keep Home
      // spinning on an expired token instead of showing the error. The user
      // retries from the error state or by logging in again.
      retry: (_, _) => null,
    );

/// Loads the logged-in user's stats and owns the log out action.
class HomeViewModel extends AsyncNotifier<UserStats> {
  @override
  Future<UserStats> build() async {
    // Mirror roast_pending / roast_level into the router gate on every stats
    // change (initial load, refresh, applyStats). The update is deferred to a
    // microtask so it never runs inside a build phase (which Riverpod forbids).
    listenSelf((_, next) {
      final stats = next.value;
      final gate = ref.read(roastGateProvider.notifier);
      Future.microtask(
        () => gate.setConfirmed(
          pending: stats?.roastPending ?? false,
          roastLevel: stats?.roastLevel ?? 0,
        ),
      );
    });

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) {
      throw const AuthException(
        code: 'INVALID_TOKEN',
        message: 'Your session has expired. Please log in again.',
      );
    }

    // Paint the last cached row instantly, then revalidate in the background so
    // a warm start shows content at once and corrects itself a moment later.
    final cached = await ref.read(homeRepositoryProvider).cachedStats(token);
    if (cached != null) {
      unawaited(_revalidate(token));
      return cached;
    }

    // Cold start with nothing cached: wait for the (cache-backed) read, which
    // serves the stored row offline and only throws a function-level error.
    final result = await ref.read(homeRepositoryProvider).fetchStats(token);
    _reportStatus(result);
    return result.value;
  }

  /// Re-reads the stats after an instant cache paint. A transport failure keeps
  /// the painted row and flags the app offline; a function-level error (a
  /// rejected token) surfaces so the session can end.
  Future<void> _revalidate(String token) async {
    try {
      final result = await ref.read(homeRepositoryProvider).fetchStats(token);
      if (!ref.mounted) return;
      state = AsyncData(result.value);
      _reportStatus(result);
    } on AuthException catch (e, st) {
      if (ref.mounted) state = AsyncError(e, st);
    }
  }

  // Deferred to a microtask so it never mutates a provider during a build.
  void _reportStatus(CacheResult<UserStats> result) => Future.microtask(() {
    if (ref.mounted) ref.read(cacheStatusProvider.notifier).apply(result);
  });

  /// Re-reads the stats in the background (e.g. when the app returns to the
  /// foreground), so a reconnect clears the offline indicator and — because a
  /// successful read bumps the read tick — flushes the outbox. No spinner: the
  /// current content stays on screen.
  Future<void> revalidate() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token != null) await _revalidate(token);
  }

  /// Reloads the stats, showing the spinner while the call is in flight.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }

  /// Pull-to-refresh: reload without flipping to the loading state, so the
  /// current content stays on screen under the RefreshIndicator's own spinner.
  Future<void> reload() async {
    state = await AsyncValue.guard(build);
  }

  /// Replaces Home's stats with a row a Cloud Code mutation just returned, so
  /// Home reflects a break or ignore without recomputing anything locally.
  void applyStats(UserStats stats) => state = AsyncData(stats);

  /// Surfaces a rejected token discovered OUTSIDE a Home fetch — the outbox
  /// flush hitting `INVALID_TOKEN`. Home's listener turns this into a redirect
  /// to Log In, exactly as a rejected fetch would.
  void endSession(AuthException error, StackTrace stackTrace) =>
      state = AsyncError(error, stackTrace);

  /// Cancels the reminders and clears the stored session. The view navigates
  /// back to Log In.
  Future<void> logOut() async {
    ref.read(roastGateProvider.notifier).reset();
    // Clear the schedule, delivery log, reminder preferences, cache and the
    // write outbox, not just the OS reminders, so the next account on the
    // device starts from nothing.
    await clearReminderData(ref);
    await ref.read(tokenStorageProvider).delete();
    // Drop the outbox's in-memory queue too (clearReminderData cleared only its
    // storage), so a replay can't fire after the session is gone.
    ref.invalidate(outboxProvider);
  }
}
