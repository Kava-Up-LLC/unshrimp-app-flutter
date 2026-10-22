import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_status.dart';
import '../../../core/cache/cached_read.dart';
import '../../auth/models/auth_exception.dart';
import '../../auth/repositories/token_storage.dart';
import '../models/stats_history.dart';
import '../repositories/history_repository.dart';

final historyViewModelProvider =
    AsyncNotifierProvider.autoDispose<HistoryViewModel, StatsHistory>(
      HistoryViewModel.new,
      // Match Home: don't let Riverpod retry a rejected token into a spinner.
      retry: (_, _) => null,
    );

/// Loads the logged-in user's per-day history, cache-first like Home: paint the
/// last stored window instantly, then revalidate in the background. Reports the
/// read outcome to the shared offline flag so the app bar shows the same chip.
class HistoryViewModel extends AsyncNotifier<StatsHistory> {
  int get _tzOffsetMin => DateTime.now().timeZoneOffset.inMinutes;

  @override
  Future<StatsHistory> build() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) {
      throw const AuthException(
        code: 'INVALID_TOKEN',
        message: 'Your session has expired. Please log in again.',
      );
    }

    final repo = ref.read(historyRepositoryProvider);
    final cached = await repo.cachedHistory(token);
    if (cached != null) {
      unawaited(_revalidate(token));
      return cached;
    }

    final result = await repo.fetchHistory(token, tzOffsetMin: _tzOffsetMin);
    _reportStatus(result);
    return result.value;
  }

  Future<void> _revalidate(String token) async {
    try {
      final result = await ref
          .read(historyRepositoryProvider)
          .fetchHistory(token, tzOffsetMin: _tzOffsetMin);
      if (!ref.mounted) return;
      state = AsyncData(result.value);
      _reportStatus(result);
    } on AuthException catch (e, st) {
      if (ref.mounted) state = AsyncError(e, st);
    }
  }

  // Deferred to a microtask so it never mutates a provider during a build.
  void _reportStatus(CacheResult<StatsHistory> result) => Future.microtask(() {
    if (ref.mounted) ref.read(cacheStatusProvider.notifier).apply(result);
  });

  /// Pull-to-refresh / retry: reload without flipping to the loading state.
  Future<void> reload() async {
    state = await AsyncValue.guard(build);
  }

  /// Reload showing the spinner (the error-state retry button).
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}
