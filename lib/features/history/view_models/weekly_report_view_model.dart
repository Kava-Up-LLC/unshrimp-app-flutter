import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_status.dart';
import '../../../core/cache/cached_read.dart';
import '../../auth/models/auth_exception.dart';
import '../../auth/repositories/token_storage.dart';
import '../../subscriptions/view_models/entitlement_view_model.dart';
import '../models/weekly_report.dart';
import '../repositories/history_repository.dart';

final weeklyReportViewModelProvider =
    AsyncNotifierProvider.autoDispose<WeeklyReportViewModel, WeeklyReport>(
      WeeklyReportViewModel.new,
      // Don't retry a rejected token into a spinner (same as History / Home).
      retry: (_, _) => null,
    );

/// Loads the weekly Spine Report for the card, cache-first like History: paint
/// the last report instantly, then revalidate on every open so a dashboard edit
/// to the verdict shows without a release.
///
/// The locked state follows the entitlement the app holds, not a cached
/// `{locked: true}` reply: watching the entitlement means that when a purchase
/// flips the user to Pro this rebuilds and fetches real data, so the card
/// unlocks without a restart. A cached locked stub is never trusted as Pro
/// data.
class WeeklyReportViewModel extends AsyncNotifier<WeeklyReport> {
  int get _tzOffsetMin => DateTime.now().timeZoneOffset.inMinutes;

  @override
  Future<WeeklyReport> build() async {
    final entitlement = await ref.watch(entitlementViewModelProvider.future);
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) {
      throw const AuthException(
        code: 'INVALID_TOKEN',
        message: 'Your session has expired. Please log in again.',
      );
    }

    // Free (or trial ended): a locked stub, no network call.
    if (!entitlement.isPro) return const WeeklyReport.locked();

    final repo = ref.read(historyRepositoryProvider);
    final cached = await repo.cachedWeeklyReport(token);
    if (cached != null && !cached.locked) {
      unawaited(_revalidate(token));
      return cached;
    }

    // No fresh Pro data cached (e.g. just unlocked): fetch now.
    final result = await repo.fetchWeeklyReport(token, tzOffsetMin: _tzOffsetMin);
    _reportStatus(result);
    return result.value;
  }

  Future<void> _revalidate(String token) async {
    try {
      final result = await ref
          .read(historyRepositoryProvider)
          .fetchWeeklyReport(token, tzOffsetMin: _tzOffsetMin);
      if (!ref.mounted) return;
      state = AsyncData(result.value);
      _reportStatus(result);
    } on AuthException catch (e, st) {
      if (ref.mounted) state = AsyncError(e, st);
    }
  }

  // Deferred to a microtask so it never mutates a provider during a build.
  void _reportStatus(CacheResult<WeeklyReport> result) => Future.microtask(() {
    if (ref.mounted) ref.read(cacheStatusProvider.notifier).apply(result);
  });

  /// Pull-to-refresh / retry: reload without flipping to the loading state.
  Future<void> reload() async {
    state = await AsyncValue.guard(build);
  }
}
