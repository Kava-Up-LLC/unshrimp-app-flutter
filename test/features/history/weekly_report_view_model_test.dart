import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/core/cache/cached_read.dart';
import 'package:unshrimp_app/features/auth/repositories/token_storage.dart';
import 'package:unshrimp_app/features/history/models/stats_history.dart';
import 'package:unshrimp_app/features/history/models/weekly_report.dart';
import 'package:unshrimp_app/features/history/repositories/history_repository.dart';
import 'package:unshrimp_app/features/history/view_models/weekly_report_view_model.dart';
import 'package:unshrimp_app/features/subscriptions/models/entitlement.dart';
import 'package:unshrimp_app/features/subscriptions/view_models/entitlement_view_model.dart';

import '../auth/fakes.dart';

const _pro = Entitlement(isPro: true, entitlement: 'pro_trial');

WeeklyReport _report({required int breaks}) => WeeklyReport(
  locked: false,
  breaks: breaks,
  ignored: 0,
  longestStreak: 1,
  breaksDelta: 0,
  verdict: 'v$breaks',
);

class _FakeHistoryRepository implements HistoryRepository {
  _FakeHistoryRepository({required this.fetched, this.cached});

  final WeeklyReport fetched;
  final WeeklyReport? cached;
  int fetchCalls = 0;

  @override
  Future<CacheResult<WeeklyReport>> fetchWeeklyReport(
    String token, {
    required int tzOffsetMin,
  }) async {
    fetchCalls++;
    return CacheResult(value: fetched, offline: false);
  }

  @override
  Future<WeeklyReport?> cachedWeeklyReport(String token) async => cached;

  // Unused by these tests.
  @override
  Future<CacheResult<StatsHistory>> fetchHistory(
    String token, {
    required int tzOffsetMin,
  }) => throw UnimplementedError();
  @override
  Future<StatsHistory?> cachedHistory(String token) => throw UnimplementedError();
}

/// An entitlement VM whose value the test sets directly (to simulate a
/// purchase flipping Free → Pro).
class _FakeEntitlementVM extends EntitlementViewModel {
  _FakeEntitlementVM(this._initial);
  final Entitlement _initial;
  @override
  Future<Entitlement> build() async => _initial;
  void set(Entitlement value) => state = AsyncData(value);
}

ProviderContainer _container(
  _FakeHistoryRepository repo, {
  Entitlement entitlement = _pro,
}) {
  final container = ProviderContainer(
    overrides: [
      historyRepositoryProvider.overrideWithValue(repo),
      tokenStorageProvider.overrideWithValue(FakeTokenStorage('t')),
      entitlementViewModelProvider.overrideWith(
        () => _FakeEntitlementVM(entitlement),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.listen(weeklyReportViewModelProvider, (_, _) {});
  return container;
}

void main() {
  test('paints the cached report instantly, then revalidates', () async {
    final repo = _FakeHistoryRepository(
      fetched: _report(breaks: 30),
      cached: _report(breaks: 20),
    );
    final container = _container(repo);

    final first = await container.read(weeklyReportViewModelProvider.future);
    expect(first.breaks, 20); // cached, shown at once

    await Future<void>.delayed(Duration.zero);
    final revalidated = container.read(weeklyReportViewModelProvider).value;
    expect(revalidated?.breaks, 30); // fresh verdict/numbers replace the cache
    expect(revalidated?.verdict, 'v30');
  });

  test('Free gets a locked stub and never calls the function', () async {
    final repo = _FakeHistoryRepository(fetched: _report(breaks: 30));
    final container = _container(repo, entitlement: Entitlement.free);

    final report = await container.read(weeklyReportViewModelProvider.future);

    expect(report.locked, isTrue);
    expect(repo.fetchCalls, 0);
  });

  test('Pro with no cache fetches fresh', () async {
    final repo = _FakeHistoryRepository(fetched: _report(breaks: 24));
    final container = _container(repo);

    final report = await container.read(weeklyReportViewModelProvider.future);

    expect(report.locked, isFalse);
    expect(report.breaks, 24);
    expect(repo.fetchCalls, 1);
  });

  test('a purchase flips Free → Pro and unlocks the card without restart', () async {
    final repo = _FakeHistoryRepository(fetched: _report(breaks: 18));
    final container = _container(repo, entitlement: Entitlement.free);

    final locked = await container.read(weeklyReportViewModelProvider.future);
    expect(locked.locked, isTrue);
    expect(repo.fetchCalls, 0);

    // Simulate the entitlement refresh after a purchase.
    (container.read(entitlementViewModelProvider.notifier) as _FakeEntitlementVM)
        .set(_pro);

    final unlocked = await container.read(weeklyReportViewModelProvider.future);
    expect(unlocked.locked, isFalse);
    expect(unlocked.breaks, 18);
    expect(repo.fetchCalls, 1);
  });
}
