import 'package:unshrimp_app/core/cache/cached_read.dart';
import 'package:unshrimp_app/features/auth/models/auth_exception.dart';
import 'package:unshrimp_app/features/notifications/models/app_notification.dart';
import 'package:unshrimp_app/features/notifications/models/delivered_reminder.dart';
import 'package:unshrimp_app/features/notifications/models/scheduled_reminder.dart';
import 'package:unshrimp_app/features/notifications/repositories/delivery_log.dart';
import 'package:unshrimp_app/features/notifications/repositories/notifications_repository.dart';

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
  FakeNotificationsRepository({
    List<AppNotification>? rows,
    this.error,
    this.cached,
    this.offline = false,
    this.asOf,
  }) : rows = rows ?? [];

  final List<AppNotification> rows;

  /// What [cachedNotifications] returns (null = nothing cached, the usual case).
  final List<AppNotification>? cached;

  /// What [fetch] reports as the cache outcome.
  final bool offline;
  final DateTime? asOf;

  /// Thrown by every call.
  AuthException? error;
  final logged = <List<DeliveredReminder>>[];
  final markedRead = <int>[];
  final deleted = <int>[];
  int markAllReadCalls = 0;

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
  Future<CacheResult<List<AppNotification>>> fetch(String token) async {
    if (error != null) throw error!;
    final sorted = [...rows]..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return CacheResult(value: sorted, offline: offline, asOf: asOf);
  }

  @override
  Future<List<AppNotification>?> cachedNotifications(String token) async =>
      cached;

  @override
  Future<void> markRead(String token, int id) async {
    if (error != null) throw error!;
    markedRead.add(id);
    final i = rows.indexWhere((n) => n.id == id);
    rows[i] = rows[i].copyWith(read: true);
  }

  @override
  Future<void> markAllRead(String token) async {
    if (error != null) throw error!;
    markAllReadCalls++;
    for (var i = 0; i < rows.length; i++) {
      rows[i] = rows[i].copyWith(read: true);
    }
  }

  @override
  Future<void> delete(String token, int id) async {
    if (error != null) throw error!;
    deleted.add(id);
    rows.removeWhere((n) => n.id == id);
  }
}

AppNotification notification(int id, DateTime sentAt, {bool read = false}) =>
    AppNotification(
      id: id,
      title: 'Unshrimp',
      body: 'Line $id',
      pack: 'default',
      sentAt: sentAt,
      read: read,
    );
