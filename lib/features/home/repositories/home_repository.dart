import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_store.dart';
import '../../../core/cache/cache_user_id.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/cloud/cloud_functions.dart';
import '../models/ignore_result.dart';
import '../models/user_stats.dart';

/// Reads and mutates the logged-in user's stats through Cloud Code. The
/// database is never touched directly from the app, and the counting (breaks,
/// ignores, streak) happens server-side — the app only reports what happened
/// and shows the row the function returns.
///
/// The read ([fetchStats]) goes through a per-user cache, so it returns the
/// last stored row offline instead of throwing; mutations are never cached.
class HomeRepository {
  const HomeRepository({
    CloudFunctions cloud = const CloudFunctions(),
    required CacheStore cache,
  }) : _cloud = cloud,
       _cache = cache;

  static const _slot = 'user_stats';

  final CloudFunctions _cloud;
  final CacheStore _cache;

  /// `get_user_stats`: the current stats row, cached per user. Idempotent read
  /// → may retry once. On a transport failure the stored row is returned with
  /// [CacheResult.offline] set; a function-level error (INVALID_TOKEN, …) still
  /// throws.
  Future<CacheResult<UserStats>> fetchStats(String token) =>
      CachedRead<UserStats>(store: _cache, decode: UserStats.fromJson).read(
        userId: cacheUserIdFromToken(token),
        slot: _slot,
        fetch: () =>
            _cloud.call('get_user_stats', {'token': token}, retry: true),
      );

  /// The last cached stats row for this token's user, or null when none is
  /// stored. Reads nothing over the network — used to paint Home instantly
  /// before [fetchStats] revalidates.
  Future<UserStats?> cachedStats(String token) async {
    final entry = await _cache.read(cacheUserIdFromToken(token), _slot);
    return entry == null ? null : UserStats.fromJson(entry.payload);
  }

  /// `register_break`: the user survived a 60 s break. [opId] is the client's
  /// id for this break (minted when the user tapped "Survived"); the server
  /// records it in `applied_ops` so a replayed flush does not double-count.
  /// Returns the updated row.
  Future<UserStats> registerBreak(String token, {required String opId}) async =>
      UserStats.fromJson(
        await _cloud.call('register_break', {'token': token, 'op_id': opId}),
      );

  /// `register_ignore`: the user let [count] reminder(s) lapse. [tzOffsetMin]
  /// is the device's UTC offset in minutes so the server can test the active
  /// window against the user's wall clock. Returns the updated row plus how
  /// many were actually counted (0 when outside the window or paused).
  Future<IgnoreResult> registerIgnore(
    String token, {
    required int count,
    required int tzOffsetMin,
  }) async {
    final data = await _cloud.call('register_ignore', {
      'token': token,
      'count': count,
      'tz_offset_min': tzOffsetMin,
    });
    return IgnoreResult(
      ignored: (data['ignored'] as num?)?.toInt() ?? 0,
      stats: UserStats.fromJson(data),
    );
  }
}

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => HomeRepository(cache: ref.read(cacheStoreProvider)),
);
