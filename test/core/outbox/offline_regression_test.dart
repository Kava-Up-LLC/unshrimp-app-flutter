import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/subscriptions/repositories/entitlement_repository.dart';

import '../../features/subscriptions/fakes.dart';
import 'package:unshrimp_app/core/cache/cache_status.dart';
import 'package:unshrimp_app/core/cache/cache_user_id.dart';
import 'package:unshrimp_app/core/cache/cached_read.dart';
import 'package:unshrimp_app/core/outbox/outbox.dart';
import 'package:unshrimp_app/core/outbox/queued_op.dart';
import 'package:unshrimp_app/features/auth/models/auth_exception.dart';
import 'package:unshrimp_app/features/auth/repositories/token_storage.dart';
import 'package:unshrimp_app/features/home/models/user_stats.dart';
import 'package:unshrimp_app/features/home/repositories/home_repository.dart';
import 'package:unshrimp_app/features/home/view_models/home_view_model.dart';
import 'package:unshrimp_app/features/roast/view_models/roast_gate_provider.dart';

import '../../features/auth/fakes.dart';
import '../../support/in_memory_prefs.dart';

/// Reads can be offline/online independently of whether the break flush
/// succeeds, so we can model "a successful read while the flush keeps failing".
class _FakeHome implements HomeRepository {
  _FakeHome(this.stats);

  UserStats stats;
  UserStats? cached;
  bool online = true; // fetchStats reports offline = !online
  bool failBreak = false; // registerBreak throws transport regardless of online
  final sent = <String>[];

  @override
  Future<CacheResult<UserStats>> fetchStats(String token) async =>
      CacheResult(value: stats, offline: !online);

  @override
  Future<UserStats?> cachedStats(String token) async => cached;

  @override
  Future<UserStats> registerBreak(String token, {required String opId}) async {
    sent.add(opId);
    if (!online || failBreak) {
      throw const AuthException(code: 'http', message: 'offline');
    }
    stats = stats.copyWith(
      breaksToday: stats.breaksToday + 1,
      roastPending: false,
    );
    return stats;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserStats _stats({
  bool roastPending = true,
  int roastLevel = 3,
  int breaksToday = 1,
}) => UserStats(
  userId: 3,
  name: 'Grace',
  archetype: null,
  currentStreak: 0,
  breaksToday: breaksToday,
  ignoredCount: 3,
  roastLevel: roastLevel,
  roastPending: roastPending,
  dailyGoal: 5,
);

QueuedOp _breakOp(String id) => QueuedOp(
  opId: id,
  function: 'register_break',
  body: const {},
  userId: cacheUserIdFromToken('t'),
  createdAt: DateTime(2026),
);

/// Pumps the microtask/event queue enough times for the revalidate → cache
/// status → runner → flush → send chain to settle.
Future<void> _pump() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

ProviderContainer _container(_FakeHome home) {
  final c = ProviderContainer(
    overrides: [
          entitlementRepositoryProvider.overrideWithValue(FakeEntitlementRepository()),
      tokenStorageProvider.overrideWithValue(FakeTokenStorage('t')),
      homeRepositoryProvider.overrideWithValue(home),
    ],
  );
  addTearDown(c.dispose);
  // The always-alive wiring UnshrimpApp holds.
  c.listen(roastReleaseFeederProvider, (_, _) {});
  c.listen(outboxProvider, (_, _) {});
  c.listen(outboxRunnerProvider, (_, _) {});
  return c;
}

void main() {
  setUp(useInMemoryPrefs);

  test('A: a read that comes back online drains the queue', () async {
    final home = _FakeHome(_stats())..cached = _stats();
    final c = _container(home);
    c.listen(homeViewModelProvider, (_, _) {});
    await c.read(outboxProvider.future);
    await c.read(homeViewModelProvider.future);
    await _pump();

    // Go offline, queue a break, and let a read mark the app offline.
    home.online = false;
    await c.read(outboxProvider.notifier).submit(_breakOp('b1'));
    await c.read(homeViewModelProvider.notifier).reload();
    await _pump();
    expect(await c.read(outboxProvider.future), isNotEmpty);
    expect(c.read(cacheStatusProvider).offline, isTrue);

    // Network back: a successful pull-to-refresh must drain the queue.
    home.online = true;
    await c.read(homeViewModelProvider.notifier).reload();
    await _pump();
    expect(
      await c.read(outboxProvider.future),
      isEmpty,
      reason: 'a successful read (offline→online) drives a flush',
    );
    expect(home.sent, contains('b1'));
  });

  test(
    'A (online timeout): a break that times out while the network is UP '
    'drains on the next successful read, with no offline→online edge',
    () async {
      final home = _FakeHome(_stats())
        ..cached = _stats(); // online the whole time
      final c = _container(home);
      c.listen(homeViewModelProvider, (_, _) {});
      await c.read(outboxProvider.future);
      await c.read(homeViewModelProvider.future);
      await _pump();

      // Online throughout, but the mutation fails on transport (a cold-start
      // timeout / 5xx) and queues. cacheStatus never goes offline.
      home.failBreak = true;
      await c.read(outboxProvider.notifier).submit(_breakOp('b1'));
      await _pump();
      expect(
        await c.read(outboxProvider.future),
        isNotEmpty,
        reason: 'queued after timeout',
      );
      expect(
        c.read(cacheStatusProvider).offline,
        isFalse,
        reason: 'never went offline',
      );

      // The function recovers; the next successful read must drain the queue,
      // even though there is no offline→online transition.
      home.failBreak = false;
      await c.read(homeViewModelProvider.notifier).reload();
      await _pump();
      expect(
        await c.read(outboxProvider.future),
        isEmpty,
        reason: 'a successful read must drain the queue while it is non-empty',
      );
      expect(home.sent, contains('b1'));
    },
  );

  test(
    'resume revalidation clears the offline indicator and drains the queue',
    () async {
      final home = _FakeHome(_stats())..cached = _stats();
      final c = _container(home);
      c.listen(homeViewModelProvider, (_, _) {});
      await c.read(outboxProvider.future);
      await c.read(homeViewModelProvider.future);
      await _pump();

      // Go offline: a read marks the app offline and a break queues.
      home.online = false;
      await c.read(outboxProvider.notifier).submit(_breakOp('b1'));
      await c.read(homeViewModelProvider.notifier).reload();
      await _pump();
      expect(c.read(cacheStatusProvider).offline, isTrue, reason: 'chip shown');
      expect(await c.read(outboxProvider.future), isNotEmpty);

      // Network back and the app resumes → Home revalidates (what
      // homeResumeProvider calls). The chip clears and the queue drains.
      home.online = true;
      await c.read(homeViewModelProvider.notifier).revalidate();
      await _pump();
      expect(
        c.read(cacheStatusProvider).offline,
        isFalse,
        reason: 'chip cleared on resume',
      );
      expect(
        await c.read(outboxProvider.future),
        isEmpty,
        reason: 'queue drained',
      );
    },
  );

  test('B: with an op queued and the flush failing, a successful fetch with '
      'roast_pending=1 never flips the roast back on', () async {
    final home = _FakeHome(_stats(roastPending: true))..cached = _stats();
    final c = _container(home);
    c.listen(homeViewModelProvider, (_, _) {});
    final pendingSeen = <bool>[];
    c.listen(roastGateProvider, (_, next) => pendingSeen.add(next.pending));
    await c.read(outboxProvider.future);
    await c.read(homeViewModelProvider.future);
    await _pump();
    expect(c.read(roastGateProvider).pending, isTrue, reason: 'roast shown');

    // Offline break queued → released.
    home.online = false;
    await c.read(outboxProvider.notifier).submit(_breakOp('b1'));
    await _pump();
    expect(c.read(roastGateProvider).pending, isFalse, reason: 'released');
    final afterRelease = pendingSeen.length;

    // Reads come back online (roast_pending STILL 1) but the break flush keeps
    // failing. This is the exact device condition: a successful fetch while the
    // op is still queued. The roast must not reappear — not even for a frame.
    home.online = true;
    home.failBreak = true;
    await c.read(homeViewModelProvider.notifier).reload();
    await _pump();

    expect(
      await c.read(outboxProvider.future),
      isNotEmpty,
      reason: 'still queued',
    );
    expect(c.read(roastGateProvider).pending, isFalse);
    expect(
      pendingSeen.sublist(afterRelease),
      everyElement(isFalse),
      reason:
          'the gate never flickered back to pending while a break was queued',
    );
  });

  test('B (cold start): a persisted queued break releases the roast even while '
      'confirmed stats say pending', () async {
    final home1 = _FakeHome(_stats(roastPending: true))..cached = _stats();
    final c1 = _container(home1);
    c1.listen(homeViewModelProvider, (_, _) {});
    await c1.read(outboxProvider.future);
    home1.online = false;
    await c1.read(outboxProvider.notifier).submit(_breakOp('b1'));
    await _pump();
    c1.dispose();

    // Cold start over the same prefs; confirmed stats still say pending.
    final home2 = _FakeHome(_stats(roastPending: true))
      ..cached = _stats()
      ..online = false;
    final c2 = _container(home2);
    c2.listen(homeViewModelProvider, (_, _) {});
    await c2.read(outboxProvider.future);
    await c2.read(homeViewModelProvider.future);
    await _pump();
    expect(
      c2.read(roastGateProvider).pending,
      isFalse,
      reason: 'persisted queued break releases the roast on cold start',
    );
  });
}
