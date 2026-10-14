import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/models/auth_exception.dart';
import '../../features/auth/repositories/token_storage.dart';
import '../../features/home/models/user_stats.dart';
import '../../features/home/repositories/home_repository.dart';
import '../../features/home/view_models/home_view_model.dart';
import '../../features/reconcile/repositories/reconcile_repository.dart';
import '../cache/cache_status.dart';
import '../cache/cache_user_id.dart';
import 'outbox_store.dart';
import 'queued_op.dart';

/// The write side of offline: a persisted queue of mutations the app owes
/// AppAmbit ([register_break], [reconcile_ignored]).
///
/// A mutation is QUEUED rather than thrown away when it hits a transport
/// failure; the queue survives a kill and reboot ([OutboxStore]). [flush] sends
/// in FIFO order, one at a time, and stops at the first transport failure,
/// leaving the rest queued. An op is DROPPED only on a function-level error that
/// can never succeed ([AuthException] `INVALID_TOKEN`), which is surfaced as a
/// session end. Server-side `applied_ops` keyed by the op's id makes a replayed
/// flush harmless.
class Outbox extends AsyncNotifier<List<QueuedOp>> {
  @override
  Future<List<QueuedOp>> build() async {
    final userId = await _currentUserId();
    if (userId == null) return const [];
    return ref.read(outboxStoreProvider).loadQueue(userId);
  }

  bool _flushing = false;

  Future<String?> _currentUserId() async {
    final token = await ref.read(tokenStorageProvider).read();
    return token == null ? null : cacheUserIdFromToken(token);
  }

  /// Persists [op] to the tail of the queue, then attempts a flush. Enqueuing is
  /// what releases the roast locally for a completed break (see [Outbox] and the
  /// roast feeder) — it happens whether or not the flush reaches AppAmbit.
  Future<void> submit(QueuedOp op) async {
    await enqueue(op);
    await flush();
  }

  /// Persists [op] without flushing. Used when the caller already knows it is
  /// offline (a reconcile that failed its own send).
  Future<void> enqueue(QueuedOp op) async {
    final next = [...(state.value ?? const <QueuedOp>[]), op];
    await ref.read(outboxStoreProvider).saveQueue(op.userId, next);
    state = AsyncData(next);
  }

  /// Sends queued ops in order, one at a time. Stops at the first transport
  /// failure (the rest stay queued for the next flush); drops an op on
  /// `INVALID_TOKEN` and ends the session.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) return;
      final userId = cacheUserIdFromToken(token);

      var queue = [...(state.value ?? const <QueuedOp>[])];
      while (queue.isNotEmpty) {
        final op = queue.first;
        UserStats stats;
        try {
          stats = await _send(op, token);
        } on AuthException catch (e, st) {
          if (e.code == 'INVALID_TOKEN') {
            // Function-level, never succeeds: drop it and end the session.
            queue = queue.sublist(1);
            await _persist(userId, queue);
            _endSession(e, st);
          }
          // Otherwise a transport failure: keep this and the rest queued.
          return;
        } catch (_) {
          return; // Any other failure is treated as transport: keep queued.
        }

        // Applied: drop it, remember it for the debug replay, reflect in Home.
        queue = queue.sublist(1);
        await _persist(userId, queue);
        await ref.read(outboxStoreProvider).saveLastApplied(userId, op);
        _applyStats(stats);
      }
    } finally {
      _flushing = false;
    }
  }

  /// Re-queues the last op that applied, under its original id, and flushes —
  /// so the next flush replays it and the server's `applied_ops` can be seen
  /// refusing to move the stats row. Debug only. Goes through the real queue,
  /// not a direct call.
  Future<void> replayLast() async {
    final userId = await _currentUserId();
    if (userId == null) return;
    final last = await ref.read(outboxStoreProvider).loadLastApplied(userId);
    if (last == null) return;
    await submit(last);
  }

  /// Records [op] as the last-applied, for a send that happened OUTSIDE the
  /// flush loop (a reconcile that went straight through while online).
  Future<void> recordApplied(QueuedOp op) =>
      ref.read(outboxStoreProvider).saveLastApplied(op.userId, op);

  Future<void> _persist(String userId, List<QueuedOp> queue) async {
    await ref.read(outboxStoreProvider).saveQueue(userId, queue);
    if (ref.mounted) state = AsyncData(queue);
  }

  Future<UserStats> _send(QueuedOp op, String token) async {
    switch (op.function) {
      case 'register_break':
        return ref
            .read(homeRepositoryProvider)
            .registerBreak(token, opId: op.opId);
      case 'reconcile_ignored':
        final ids = (op.body['ids'] as List)
            .map((e) => (e as num).toInt())
            .toList();
        final result = await ref
            .read(reconcileRepositoryProvider)
            .reconcileIgnored(
              token,
              ids: ids,
              tzOffsetMin: (op.body['tz_offset_min'] as num).toInt(),
              opId: op.opId,
            );
        return result.stats;
      default:
        throw StateError('Unknown outbox function ${op.function}');
    }
  }

  void _applyStats(UserStats stats) {
    if (ref.exists(homeViewModelProvider)) {
      ref.read(homeViewModelProvider.notifier).applyStats(stats);
    }
  }

  void _endSession(AuthException e, StackTrace st) {
    if (ref.exists(homeViewModelProvider)) {
      ref.read(homeViewModelProvider.notifier).endSession(e, st);
    }
  }
}

final outboxProvider = AsyncNotifierProvider<Outbox, List<QueuedOp>>(
  Outbox.new,
);

/// Flushes the outbox on launch, on resume, and whenever a read brings the app
/// back online. Watched by the root widget so it lives as long as the app (and
/// so [outboxProvider] loads its queue at startup).
final outboxRunnerProvider = Provider<void>((ref) {
  Future<void> run() async {
    try {
      // Wait for the queue to load from disk FIRST. flush() reads the in-memory
      // state, so flushing before build() resolves would see an empty queue and
      // silently do nothing — which is why the launch flush used to be a no-op.
      await ref.read(outboxProvider.future);
      await ref.read(outboxProvider.notifier).flush();
    } catch (_) {
      // Best-effort: a failed flush leaves the queue intact for the next one.
    }
  }

  // Flush after ANY successful read while the queue is non-empty (flush is a
  // no-op when empty). This catches both a reconnect (offline→online) and a
  // mutation that queued after a transport timeout/5xx while the app was online
  // — in that case cacheStatus never flipped, so an edge-only trigger would
  // strand the op until the next launch/resume. Registered first so it is wired
  // even if the lifecycle listener below is unavailable (e.g. no binding under
  // test).
  ref.listen(readSuccessTickProvider, (_, _) => unawaited(run()));

  unawaited(run());
  final listener = AppLifecycleListener(onResume: () => unawaited(run()));
  ref.onDispose(listener.dispose);
});
