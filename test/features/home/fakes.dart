import 'package:move_well_app/features/auth/models/auth_exception.dart';
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
  FakeHomeRepository({this.stats = testStats, this.error});

  final UserStats stats;
  final AuthException? error;
  int calls = 0;

  @override
  Future<UserStats> fetchStats(String token) async {
    calls++;
    if (error != null) throw error!;
    return stats;
  }
}
