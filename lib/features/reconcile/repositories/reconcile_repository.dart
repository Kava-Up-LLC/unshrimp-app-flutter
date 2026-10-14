import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cloud/cloud_functions.dart';
import '../../home/models/ignore_result.dart';
import '../../home/models/user_stats.dart';
import '../models/pending_reminder.dart';

/// Reads the user's un-reconciled reminders and counts them ignored, through the
/// `get_pending_reminders` and `reconcile_ignored` Cloud Code functions.
class ReconcileRepository {
  const ReconcileRepository([this._cloud = const CloudFunctions()]);

  final CloudFunctions _cloud;

  /// Reminders delivered but neither opened nor already marked ignored.
  /// Idempotent read → may retry once.
  Future<List<PendingReminder>> fetchPending(String token) async {
    final data = await _cloud.call(
      'get_pending_reminders',
      {'token': token},
      retry: true,
    );
    final rows = data['reminders'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(PendingReminder.fromJson)
        .toList();
  }

  /// `reconcile_ignored`: in one server-side transaction, marks the given rows
  /// `was_ignored` and raises the ignore count by however many were still
  /// pending, returning the updated stats row plus how many were actually
  /// counted (0 when outside the active window or paused). [tzOffsetMin] is the
  /// device's UTC offset so the server can test the window against the user's
  /// wall clock. The call is idempotent — already-marked rows count for nothing
  /// — so it is the one mutation safe to [retry] on a transient failure.
  Future<IgnoreResult> reconcileIgnored(
    String token, {
    required List<int> ids,
    required int tzOffsetMin,
    required String opId,
  }) async {
    final data = await _cloud.call('reconcile_ignored', {
      'token': token,
      'ids': ids,
      'tz_offset_min': tzOffsetMin,
      'op_id': opId,
    }, retry: true);
    return IgnoreResult(
      ignored: (data['counted'] as num?)?.toInt() ?? 0,
      stats: UserStats.fromJson(data),
    );
  }
}

final reconcileRepositoryProvider = Provider<ReconcileRepository>(
  (ref) => const ReconcileRepository(),
);
