import 'package:move_well_app/features/reconcile/models/pending_reminder.dart';
import 'package:move_well_app/features/reconcile/repositories/reconcile_repository.dart';

class FakeReconcileRepository implements ReconcileRepository {
  FakeReconcileRepository([List<PendingReminder> pending = const []])
    : _pending = List.of(pending);

  List<PendingReminder> _pending;
  final markedIds = <List<int>>[];
  int fetchCalls = 0;

  @override
  Future<List<PendingReminder>> fetchPending(String token) async {
    fetchCalls++;
    return List.of(_pending);
  }

  @override
  Future<int> markIgnored(String token, List<int> ids) async {
    markedIds.add(ids);
    _pending = _pending.where((r) => !ids.contains(r.id)).toList();
    return ids.length;
  }
}
