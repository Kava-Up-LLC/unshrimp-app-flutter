import 'package:move_well_app/features/auth/models/auth_exception.dart';
import 'package:move_well_app/features/home/models/ignore_result.dart';
import 'package:move_well_app/features/home/models/user_stats.dart';
import 'package:move_well_app/features/home/repositories/home_repository.dart';

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
    UserStats? afterIgnore,
    this.ignoredResult,
  }) : afterBreak = afterBreak ?? stats,
       afterIgnore = afterIgnore ?? stats;

  final UserStats stats;
  final AuthException? error;

  /// The row the mutations return (defaults to [stats]).
  final UserStats afterBreak;
  final UserStats afterIgnore;

  /// What `register_ignore` reports as counted; defaults to the requested
  /// count (everything counted). Set to 0 to simulate outside-window/paused.
  final int? ignoredResult;

  int calls = 0;
  int breakCalls = 0;
  int ignoreCalls = 0;
  int? lastIgnoreCount;
  int? lastTzOffsetMin;

  @override
  Future<UserStats> fetchStats(String token) async {
    calls++;
    if (error != null) throw error!;
    return stats;
  }

  @override
  Future<UserStats> registerBreak(String token) async {
    breakCalls++;
    if (error != null) throw error!;
    return afterBreak;
  }

  @override
  Future<IgnoreResult> registerIgnore(
    String token, {
    required int count,
    required int tzOffsetMin,
  }) async {
    ignoreCalls++;
    lastIgnoreCount = count;
    lastTzOffsetMin = tzOffsetMin;
    if (error != null) throw error!;
    return IgnoreResult(ignored: ignoredResult ?? count, stats: afterIgnore);
  }
}
