import 'package:unshrimp_app/core/cache/cached_read.dart';
import 'package:unshrimp_app/features/auth/models/auth_exception.dart';
import 'package:unshrimp_app/features/home/models/user_stats.dart';
import 'package:unshrimp_app/features/home/repositories/home_repository.dart';

const testStats = UserStats(
  userId: 3,
  name: 'Grace Hopper',
  archetype: null,
  currentStreak: 4,
  breaksToday: 2,
  ignoredCount: 1,
  roastLevel: 3,
  roastPending: false,
);

class FakeHomeRepository implements HomeRepository {
  FakeHomeRepository({
    this.stats = testStats,
    this.error,
    UserStats? afterBreak,
    this.cached,
    this.offline = false,
    this.asOf,
  }) : afterBreak = afterBreak ?? stats;

  final UserStats stats;
  final AuthException? error;

  /// The row [cachedStats] returns (null = nothing cached, the usual case).
  final UserStats? cached;

  /// What [fetchStats] reports as the cache outcome.
  final bool offline;
  final DateTime? asOf;

  /// The row the mutations return (defaults to [stats]).
  final UserStats afterBreak;

  int calls = 0;
  int breakCalls = 0;

  @override
  Future<CacheResult<UserStats>> fetchStats(String token) async {
    calls++;
    if (error != null) throw error!;
    return CacheResult(value: stats, offline: offline, asOf: asOf);
  }

  @override
  Future<UserStats?> cachedStats(String token) async => cached;

  @override
  Future<UserStats> registerBreak(String token, {required String opId}) async {
    breakCalls++;
    if (error != null) throw error!;
    return afterBreak;
  }
}
