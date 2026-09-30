import 'package:move_well_app/features/auth/models/auth_exception.dart';
import 'package:move_well_app/features/notifications/models/app_notification.dart';
import 'package:move_well_app/features/notifications/models/delivered_reminder.dart';
import 'package:move_well_app/features/notifications/models/scheduled_reminder.dart';
import 'package:move_well_app/features/notifications/repositories/delivery_log.dart';
import 'package:move_well_app/features/notifications/repositories/notifications_repository.dart';

/// In-memory [DeliveryLog].
class FakeDeliveryLog implements DeliveryLog {
  FakeDeliveryLog({this.schedule = const [], this.lastSync});

  List<ScheduledReminder> schedule;
  DateTime? lastSync;

  @override
  Future<List<ScheduledReminder>> readSchedule() async => schedule;

  @override
  Future<void> writeSchedule(List<ScheduledReminder> schedule) async =>
      this.schedule = schedule;

  @override
  Future<DateTime?> readLastSync() async => lastSync;

  @override
  Future<void> writeLastSync(DateTime time) async => lastSync = time;

  @override
  Future<void> clear() async {
    schedule = const [];
    lastSync = null;
  }
}

/// Stands in for the three Cloud Code functions over an in-memory table.
class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository({List<AppNotification>? rows, this.error})
    : rows = rows ?? [];

  final List<AppNotification> rows;

  /// Thrown by every call.
  AuthException? error;
  final logged = <List<DeliveredReminder>>[];
  final markedRead = <int>[];

  @override
  Future<void> log(String token, List<DeliveredReminder> reminders) async {
    if (error != null) throw error!;
    logged.add(reminders);
    for (final r in reminders) {
      rows.add(
        AppNotification(
          id: rows.length + 1,
          title: r.title,
          body: r.body,
          pack: r.pack,
          sentAt: r.sentAt,
          read: false,
          reminderKey: r.reminderKey,
        ),
      );
    }
  }

  @override
  Future<List<AppNotification>> fetch(String token) async {
    if (error != null) throw error!;
    return [...rows]..sort((a, b) => b.sentAt.compareTo(a.sentAt));
  }

  @override
  Future<void> markRead(String token, int id) async {
    if (error != null) throw error!;
    markedRead.add(id);
    final i = rows.indexWhere((n) => n.id == id);
    rows[i] = rows[i].copyWith(read: true);
  }
}

AppNotification notification(int id, DateTime sentAt, {bool read = false}) =>
    AppNotification(
      id: id,
      title: 'MoveWell',
      body: 'Line $id',
      pack: 'default',
      sentAt: sentAt,
      read: read,
    );
