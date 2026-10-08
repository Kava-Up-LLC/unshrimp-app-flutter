import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cloud/cloud_functions.dart';
import '../models/pending_reminder.dart';

/// Reads the user's un-reconciled reminders and marks them ignored, through the
/// `get_pending_reminders` and `mark_ignored` Cloud Code functions.
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

  /// Marks the given rows `was_ignored`. Returns how many were updated.
  Future<int> markIgnored(String token, List<int> ids) async {
    final data = await _cloud.call('mark_ignored', {'token': token, 'ids': ids});
    return (data['marked'] as num?)?.toInt() ?? 0;
  }
}

final reconcileRepositoryProvider = Provider<ReconcileRepository>(
  (ref) => const ReconcileRepository(),
);
