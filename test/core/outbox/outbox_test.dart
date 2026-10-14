import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/core/cache/cache_user_id.dart';
import 'package:unshrimp_app/core/cache/cached_read.dart';
import 'package:unshrimp_app/core/outbox/outbox.dart';
import 'package:unshrimp_app/core/outbox/queued_op.dart';
import 'package:unshrimp_app/core/router/app_routes.dart';
import 'package:unshrimp_app/core/router/roast_redirect.dart';
import 'package:unshrimp_app/features/auth/models/auth_exception.dart';
import 'package:unshrimp_app/features/auth/repositories/token_storage.dart';
import 'package:unshrimp_app/features/home/models/user_stats.dart';
import 'package:unshrimp_app/features/home/repositories/home_repository.dart';
import 'package:unshrimp_app/features/home/view_models/home_display_provider.dart';
import 'package:unshrimp_app/features/home/view_models/home_view_model.dart';
import 'package:unshrimp_app/features/roast/view_models/roast_gate_provider.dart';

import '../../features/auth/fakes.dart';
import '../../support/in_memory_prefs.dart';

/// A fake [HomeRepository] that models the server's `applied_ops` dedup: a
/// replayed `op_id` is sent again but does NOT move the stats a second time.
class _FakeHome implements HomeRepository {
  _FakeHome(this.stats);

  UserStats stats;
  final applied = <String>{};
  final sent = <String>[];
  bool offline = false;
  String? failOn;
  AuthException? breakError;

  @override
  Future<CacheResult<UserStats>> fetchStats(String token) async =>
      CacheResult(value: stats, offline: false);

  @override
  Future<UserStats?> cachedStats(String token) async => null;

  @override
  Future<UserStats> registerBreak(String token, {required String opId}) async {
    sent.add(opId);
    if (breakError != null) throw breakError!;
    if (offline || opId == failOn) {
      throw const AuthException(code: 'http', message: 'offline');
    }
    // Dedup, exactly as the real `applied_ops` guard: a new op_id applies; a
    // replayed one is a no-op and the row is returned unchanged.
    if (applied.add(opId)) {
      stats = stats.copyWith(
        breaksToday: stats.breaksToday + 1,
        roastPending: false,
      );
    }
    return stats;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserStats _stats({
  int streak = 4,
  int breaksToday = 2,
  bool roastPending = false,
  int roastLevel = 3,
}) => UserStats(
  userId: 3,
  name: 'Grace',
  archetype: null,
  currentStreak: streak,
  breaksToday: breaksToday,
  ignoredCount: 0,
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

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 10));

ProviderContainer _container(_FakeHome home) {
  final c = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(FakeTokenStorage('t')),
      homeRepositoryProvider.overrideWithValue(home),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  setUp(useInMemoryPrefs);

  test('a queued op survives a restart', () async {
    final home = _FakeHome(_stats())..offline = true;
    final c1 = _container(home);
    await c1.read(outboxProvider.future);
    await c1.read(outboxProvider.notifier).submit(_breakOp('op-1'));
    expect(
      (await c1.read(outboxProvider.future)).map((o) => o.opId),
      ['op-1'],
      reason: 'offline: the op is kept, not thrown away',
    );
    c1.dispose();

    // "Restart": a fresh container over the same (in-memory) prefs.
    final c2 = _container(home);
    final restored = await c2.read(outboxProvider.future);
    expect(restored.map((o) => o.opId), ['op-1']);
  });

  test('flush sends queued ops in FIFO order, one at a time', () async {
    final home = _FakeHome(_stats(breaksToday: 0));
    final c = _container(home);
    await c.read(outboxProvider.future);
    final outbox = c.read(outboxProvider.notifier);

    await outbox.enqueue(_breakOp('op-a'));
    await outbox.enqueue(_breakOp('op-b'));
    await outbox.flush();

    expect(home.sent, ['op-a', 'op-b']);
    expect(await c.read(outboxProvider.future), isEmpty);
  });

  test('flush stops at the first transport failure and keeps the rest '
      'queued', () async {
    final home = _FakeHome(_stats())..failOn = 'op-a';
    final c = _container(home);
    await c.read(outboxProvider.future);
    final outbox = c.read(outboxProvider.notifier);

    await outbox.enqueue(_breakOp('op-a'));
    await outbox.enqueue(_breakOp('op-b'));
    await outbox.flush();

    expect(home.sent, ['op-a'], reason: 'op-b is never attempted');
    expect((await c.read(outboxProvider.future)).map((o) => o.opId), [
      'op-a',
      'op-b',
    ]);
  });

  test('a replayed op with the same op_id leaves the stats row untouched '
      'and adds no second applied_ops row', () async {
    final home = _FakeHome(_stats(breaksToday: 2));
    final c = _container(home);
    await c.read(outboxProvider.future);
    final outbox = c.read(outboxProvider.notifier);

    await outbox.submit(_breakOp('op-x'));
    expect(home.stats.breaksToday, 3);
    expect(home.applied, {'op-x'});

    // Replay the last applied op, under its original id.
    await outbox.replayLast();

    expect(home.sent, ['op-x', 'op-x'], reason: 'sent twice');
    expect(home.applied, {'op-x'}, reason: 'only one applied_ops row');
    expect(home.stats.breaksToday, 3, reason: 'the row does not move');
  });

  test('a function-level error (INVALID_TOKEN) drops the op', () async {
    final home = _FakeHome(_stats())
      ..breakError = const AuthException(code: 'INVALID_TOKEN', message: 'x');
    final c = _container(home);
    await c.read(outboxProvider.future);

    await c.read(outboxProvider.notifier).submit(_breakOp('op-dead'));

    expect(
      await c.read(outboxProvider.future),
      isEmpty,
      reason: 'a never-succeeds error drops the op instead of looping forever',
    );
  });

  test(
    'a queued-only break shows the break but never advances the streak',
    () async {
      final home = _FakeHome(_stats(streak: 5, breaksToday: 2))..offline = true;
      final c = _container(home);
      c.listen(homeViewModelProvider, (_, _) {});
      c.listen(outboxProvider, (_, _) {});
      await c.read(homeViewModelProvider.future);
      await c.read(outboxProvider.future);

      await c.read(outboxProvider.notifier).submit(_breakOp('op-s'));
      await _settle();

      final display = c.read(homeDisplayProvider).requireValue;
      expect(
        display.stats.breaksToday,
        3,
        reason: 'break shown optimistically',
      );
      expect(display.waitingToSync, isTrue);
      expect(
        display.stats.currentStreak,
        5,
        reason: 'the streak only moves on a real response',
      );
    },
  );

  test('a reconciliation and a completed break interleave: the gate and the '
      'redirect follow the applied stats', () async {
    final home = _FakeHome(_stats(roastPending: false));
    final c = _container(home);
    c.listen(homeViewModelProvider, (_, _) {});
    c.listen(outboxProvider, (_, _) {});
    c.listen(roastReleaseFeederProvider, (_, _) {});
    await c.read(homeViewModelProvider.future);
    await c.read(outboxProvider.future);
    await _settle();

    // A reconciliation lands and sets roast_pending: the router forces the
    // gated screens to the roast.
    c
        .read(homeViewModelProvider.notifier)
        .applyStats(_stats(roastPending: true, roastLevel: 4));
    await _settle();
    expect(c.read(roastGateProvider).pending, isTrue);
    expect(
      roastRedirect(
        location: AppRoutes.home,
        pending: c.read(roastGateProvider).pending,
      ),
      AppRoutes.roast,
    );

    // A completed break is queued OFFLINE: it releases the roast locally (the
    // user is let out) while the confirmed row still says pending.
    home.offline = true;
    await c.read(outboxProvider.notifier).submit(_breakOp('op-i'));
    await _settle();
    expect(c.read(roastGateProvider).pending, isFalse, reason: 'released');
    expect(
      roastRedirect(
        location: AppRoutes.roast,
        pending: c.read(roastGateProvider).pending,
      ),
      AppRoutes.home,
    );

    // The break flushes online: the server clears roast_pending in the same
    // transaction and the queue empties; the gate stays not-pending.
    home.offline = false;
    await c.read(outboxProvider.notifier).flush();
    await _settle();
    expect(await c.read(outboxProvider.future), isEmpty);
    expect(c.read(roastGateProvider).pending, isFalse);
  });
}
