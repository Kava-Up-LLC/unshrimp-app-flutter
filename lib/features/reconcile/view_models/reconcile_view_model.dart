import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_user_id.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/outbox/op_id.dart';
import '../../../core/outbox/outbox.dart';
import '../../../core/outbox/queued_op.dart';
import '../../auth/models/auth_exception.dart';
import '../../auth/repositories/token_storage.dart';
import '../../home/view_models/home_view_model.dart';
import '../../settings/repositories/settings_repository.dart';
import '../models/pending_reminder.dart';
import '../models/reconcile_outcome.dart';
import '../repositories/reconcile_repository.dart';

final reconcileViewModelProvider = Provider<ReconcileViewModel>(
  ReconcileViewModel.new,
);

/// Notices the reminders the user ignored and reports them to the server once.
///
/// Runs on launch and resume (all counting is server-side; the app only reports
/// what happened). A reminder is "expired" when, in the DEVICE's local time,
/// now is past its grace window AND it was sent inside the active window.
class ReconcileViewModel {
  ReconcileViewModel(this.ref);

  final Ref ref;

  /// Whether [sentAtUtc] counts as an ignored reminder at [now] (all local).
  static bool isExpired({
    required DateTime sentAtUtc,
    required DateTime now,
    required int graceMin,
    required String activeStart,
    required String activeEnd,
  }) {
    final sentLocal = sentAtUtc.toLocal();
    if (!now.isAfter(sentLocal.add(Duration(minutes: graceMin)))) return false;

    final startMin = _toMinutes(activeStart);
    final endMin = _toMinutes(activeEnd);
    if (startMin == null || endMin == null) return false;

    final sentMin = sentLocal.hour * 60 + sentLocal.minute;
    return sentMin >= startMin && sentMin < endMin;
  }

  /// [forceAll] (debug) treats every pending reminder as expired, skipping the
  /// grace/window checks so a demo need not wait for the grace window.
  Future<ReconcileOutcome> run({bool forceAll = false}) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return const ReconcileOutcome.nothingPending();

    final pending = await ref
        .read(reconcileRepositoryProvider)
        .fetchPending(token);
    if (pending.isEmpty) return const ReconcileOutcome.nothingPending();

    final List<PendingReminder> expired;
    if (forceAll) {
      expired = pending;
    } else {
      final settings =
          (await ref.read(settingsRepositoryProvider).fetch(token)).value;
      final now = DateTime.now();
      expired = pending
          .where(
            (r) => isExpired(
              sentAtUtc: r.sentAtUtc,
              now: now,
              graceMin: settings.graceWindowMin,
              activeStart: settings.activeStart,
              activeEnd: settings.activeEnd,
            ),
          )
          .toList();
    }
    if (expired.isEmpty) return const ReconcileOutcome.nothingPending();

    // One op for this reconcile run. The id is minted HERE, at the moment we
    // decide these reminders expired — not at flush time — so a retry (or the
    // outbox draining it later) replays under one id and the server counts it
    // once.
    final op = QueuedOp(
      opId: newOpId(),
      function: 'reconcile_ignored',
      body: {
        'ids': expired.map((r) => r.id).toList(),
        'tz_offset_min': DateTime.now().timeZoneOffset.inMinutes,
      },
      userId: cacheUserIdFromToken(token),
      createdAt: DateTime.now(),
    );

    // One atomic, idempotent Cloud Code call marks the rows and counts them in
    // a single transaction; it re-checks the window/paused state at call time.
    // (An earlier version split this into two calls, which could double-count if
    // the app died between them.) On a transport failure the op is queued and
    // retried on the next flush instead of being lost.
    try {
      final result = await ref
          .read(reconcileRepositoryProvider)
          .reconcileIgnored(
            token,
            ids: (op.body['ids'] as List).cast<int>(),
            tzOffsetMin: op.body['tz_offset_min'] as int,
            opId: op.opId,
          );

      // Outside active hours or paused: the business rule is to count nothing.
      if (result.ignored == 0) return const ReconcileOutcome.notCounted();

      if (ref.exists(homeViewModelProvider)) {
        ref.read(homeViewModelProvider.notifier).applyStats(result.stats);
      }
      await ref.read(outboxProvider.notifier).recordApplied(op);
      return ReconcileOutcome.counted(
        ignored: result.ignored,
        batteryPercent: result.stats.batteryPercent,
      );
    } on AuthException catch (e) {
      // Transport failure → queue for the next flush. A rejected token
      // (INVALID_TOKEN) never succeeds, so it is not queued — it rethrows and
      // ends the session upstream.
      if (isTransportError(e.code)) {
        await ref.read(outboxProvider.notifier).enqueue(op);
      }
      rethrow;
    }
  }

  static int? _toMinutes(String hhmm) {
    final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(hhmm);
    if (match == null) return null;
    return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  }
}
