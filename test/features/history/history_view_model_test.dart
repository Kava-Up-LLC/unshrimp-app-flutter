import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/core/cache/cache_status.dart';
import 'package:unshrimp_app/core/cache/cached_read.dart';
import 'package:unshrimp_app/features/auth/repositories/token_storage.dart';
import 'package:unshrimp_app/features/history/models/stats_history.dart';
import 'package:unshrimp_app/features/history/models/weekly_report.dart';
import 'package:unshrimp_app/features/history/repositories/history_repository.dart';
import 'package:unshrimp_app/features/history/view_models/history_view_model.dart';

import '../auth/fakes.dart';

StatsHistory _history(int bestStreak) => StatsHistory.fromJson({
  'weeks': 1,
  'daily_goal': 4,
  'best_streak': bestStreak,
  'goal_met_days': bestStreak,
  'days': [
    for (var i = 1; i <= 7; i++)
      {'day': '2024-01-0$i', 'breaks': 0, 'ignored': 0, 'goal_met': 0},
  ],
});

class _FakeHistoryRepository implements HistoryRepository {
  _FakeHistoryRepository({
    required this.fetched,
    this.cached,
    this.offline = false,
    this.asOf,
  });

  final StatsHistory fetched;
  final StatsHistory? cached;
  final bool offline;
  final DateTime? asOf;

  @override
  Future<CacheResult<StatsHistory>> fetchHistory(
    String token, {
    required int tzOffsetMin,
  }) async => CacheResult(value: fetched, offline: offline, asOf: asOf);

  @override
  Future<StatsHistory?> cachedHistory(String token) async => cached;

  @override
  Future<CacheResult<WeeklyReport>> fetchWeeklyReport(
    String token, {
    required int tzOffsetMin,
  }) async => const CacheResult(value: WeeklyReport.locked(), offline: false);

  @override
  Future<WeeklyReport?> cachedWeeklyReport(String token) async => null;
}

ProviderContainer _container(_FakeHistoryRepository repo) {
  final container = ProviderContainer(
    overrides: [
      historyRepositoryProvider.overrideWithValue(repo),
      tokenStorageProvider.overrideWithValue(FakeTokenStorage('t')),
    ],
  );
  addTearDown(container.dispose);
  container.listen(historyViewModelProvider, (_, _) {});
  return container;
}

void main() {
  test('a transport failure keeps History on cached data and flags offline', () async {
    final asOf = DateTime(2024, 1, 1, 10, 42);
    final repo = _FakeHistoryRepository(
      fetched: _history(2),
      offline: true,
      asOf: asOf,
    );
    final container = _container(repo);

    final history = await container.read(historyViewModelProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(history.bestStreak, 2);
    final status = container.read(cacheStatusProvider);
    expect(status.offline, isTrue);
    expect(status.asOf, asOf);
  });

  test('paints the cached window instantly, then revalidates online', () async {
    final repo = _FakeHistoryRepository(fetched: _history(5), cached: _history(2));
    final container = _container(repo);

    // Cold read returns the cached window at once.
    final first = await container.read(historyViewModelProvider.future);
    expect(first.bestStreak, 2);

    // Background revalidation replaces it with the fresh window and clears offline.
    await Future<void>.delayed(Duration.zero);
    final revalidated = container.read(historyViewModelProvider).value;
    expect(revalidated?.bestStreak, 5);
    expect(container.read(cacheStatusProvider).offline, isFalse);
  });
}
