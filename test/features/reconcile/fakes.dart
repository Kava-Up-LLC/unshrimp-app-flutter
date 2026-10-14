import 'package:move_well_app/features/home/models/ignore_result.dart';
import 'package:move_well_app/features/reconcile/models/pending_reminder.dart';
import 'package:move_well_app/features/reconcile/repositories/reconcile_repository.dart';

import '../home/fakes.dart';

class FakeReconcileRepository implements ReconcileRepository {
  FakeReconcileRepository([List<PendingReminder> pending = const [], this.counted])
    : _pending = List.of(pending);

  List<PendingReminder> _pending;

  /// How many the server counts; null means all of them (everything counted).
  /// 0 simulates outside-window/paused: nothing counted, rows stay pending.
  final int? counted;

  final reconciledIds = <List<int>>[];
  int fetchCalls = 0;
  int reconcileCalls = 0;
  int? lastTzOffsetMin;
  String? lastOpId;

  @override
  Future<List<PendingReminder>> fetchPending(String token) async {
    fetchCalls++;
    return List.of(_pending);
  }

  @override
  Future<IgnoreResult> reconcileIgnored(
    String token, {
    required List<int> ids,
    required int tzOffsetMin,
    required String opId,
  }) async {
    reconcileCalls++;
    lastTzOffsetMin = tzOffsetMin;
    lastOpId = opId;
    final n = counted ?? ids.length;
    if (n > 0) {
      reconciledIds.add(ids);
      // Marked rows stop appearing in get_pending_reminders, as on the server.
      _pending = _pending.where((r) => !ids.contains(r.id)).toList();
    }
    return IgnoreResult(ignored: n, stats: testStats);
  }
}
