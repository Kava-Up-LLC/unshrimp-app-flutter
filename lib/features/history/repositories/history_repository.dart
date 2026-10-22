import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_store.dart';
import '../../../core/cache/cache_user_id.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/cloud/cloud_functions.dart';
import '../models/stats_history.dart';
import '../models/weekly_report.dart';

/// Reads the logged-in user's per-day history through the `get_stats_history`
/// Cloud Code function, behind a per-user cache so the History screen opens
/// offline with the last thing it saw (same pattern as [HomeRepository]).
class HistoryRepository {
  const HistoryRepository({
    CloudFunctions cloud = const CloudFunctions(),
    required CacheStore cache,
  }) : _cloud = cloud,
       _cache = cache;

  static const _slot = 'stats_history';
  static const _weeklySlot = 'weekly_report';

  /// How many weeks the screen asks for. Three recent weeks; weeks with no
  /// activity are hidden on screen, so this is just the furthest it looks back.
  /// A later episode gates the window to today-only for Free users.
  static const weeks = 3;

  final CloudFunctions _cloud;
  final CacheStore _cache;

  /// `get_stats_history`: the last [weeks] weeks, cached per user. Idempotent
  /// read → may retry once. On a transport failure the stored payload is
  /// returned with [CacheResult.offline] set; a function-level error throws.
  Future<CacheResult<StatsHistory>> fetchHistory(
    String token, {
    required int tzOffsetMin,
  }) => CachedRead<StatsHistory>(store: _cache, decode: StatsHistory.fromJson)
      .read(
        userId: cacheUserIdFromToken(token),
        slot: _slot,
        fetch: () => _cloud.call('get_stats_history', {
          'token': token,
          'weeks': weeks,
          'tz_offset_min': tzOffsetMin,
        }, retry: true),
      );

  /// The last cached history for this token's user, or null when none is
  /// stored. Reads nothing over the network — used to paint the screen
  /// instantly before [fetchHistory] revalidates.
  Future<StatsHistory?> cachedHistory(String token) async {
    final entry = await _cache.read(cacheUserIdFromToken(token), _slot);
    return entry == null ? null : StatsHistory.fromJson(entry.payload);
  }

  /// `get_weekly_report`: last complete week's Spine Report, cached per user
  /// like [fetchHistory]. Idempotent read → may retry once; a transport failure
  /// serves the stored payload, a function-level error throws.
  Future<CacheResult<WeeklyReport>> fetchWeeklyReport(
    String token, {
    required int tzOffsetMin,
  }) => CachedRead<WeeklyReport>(store: _cache, decode: WeeklyReport.fromJson)
      .read(
        userId: cacheUserIdFromToken(token),
        slot: _weeklySlot,
        fetch: () => _cloud.call('get_weekly_report', {
          'token': token,
          'tz_offset_min': tzOffsetMin,
        }, retry: true),
      );

  /// The last cached weekly report for this token's user, or null when none is
  /// stored. Used to paint the card instantly before [fetchWeeklyReport]
  /// revalidates.
  Future<WeeklyReport?> cachedWeeklyReport(String token) async {
    final entry = await _cache.read(cacheUserIdFromToken(token), _weeklySlot);
    return entry == null ? null : WeeklyReport.fromJson(entry.payload);
  }
}

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(cache: ref.read(cacheStoreProvider)),
);
