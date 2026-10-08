import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cloud/cloud_functions.dart';
import '../models/ignore_result.dart';
import '../models/user_stats.dart';

/// Reads and mutates the logged-in user's stats through Cloud Code. The
/// database is never touched directly from the app, and the counting (breaks,
/// ignores, streak) happens server-side — the app only reports what happened
/// and shows the row the function returns.
class HomeRepository {
  const HomeRepository([this._cloud = const CloudFunctions()]);

  final CloudFunctions _cloud;

  /// `get_user_stats`: the current stats row. Idempotent read → may retry once.
  Future<UserStats> fetchStats(String token) async => UserStats.fromJson(
    await _cloud.call('get_user_stats', {'token': token}, retry: true),
  );

  /// `register_break`: the user survived a 60 s break. Returns the updated row.
  Future<UserStats> registerBreak(String token) async =>
      UserStats.fromJson(await _cloud.call('register_break', {'token': token}));

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
  (ref) => const HomeRepository(),
);
