/// A row of the user's `notifications` table, as returned by
/// `get_notifications`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.pack,
    required this.sentAt,
    required this.read,
    this.wasIgnored = false,
    this.reminderKey,
    this.kind = 'reminder',
    this.open,
  });

  final int id;
  final String title;
  final String body;

  /// Sarcasm pack the text came from, e.g. `default` or `halloween`.
  final String pack;
  final DateTime sentAt;
  final bool read;

  /// True when this reminder was reconciled as ignored (the user let it lapse).
  final bool wasIgnored;

  /// Key of the scheduled reminder behind this row; null for older rows.
  final String? reminderKey;

  /// `reminder` (the default) or `push` for a received push stored here.
  final String kind;

  /// A push row's go_router open key; tapping the row navigates there.
  final String? open;

  /// True when this row is a received push, not a reminder.
  bool get isPush => kind == 'push';

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    title: title,
    body: body,
    pack: pack,
    sentAt: sentAt,
    read: read ?? this.read,
    wasIgnored: wasIgnored,
    reminderKey: reminderKey,
    kind: kind,
    open: open,
  );

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['id'] as num).toInt(),
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        pack: json['pack']?.toString() ?? '',
        sentAt:
            DateTime.tryParse(json['sent_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        read: json['read'] == true,
        wasIgnored: json['was_ignored'] == true,
        reminderKey: json['reminder_key']?.toString(),
        kind: json['kind']?.toString() ?? 'reminder',
        open: json['open']?.toString(),
      );
}
