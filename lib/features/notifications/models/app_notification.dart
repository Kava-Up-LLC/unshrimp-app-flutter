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
    this.reminderKey,
  });

  final int id;
  final String title;
  final String body;

  /// Sarcasm pack the text came from, e.g. `default` or `halloween`.
  final String pack;
  final DateTime sentAt;
  final bool read;

  /// Key of the scheduled reminder behind this row; null for older rows.
  final String? reminderKey;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    title: title,
    body: body,
    pack: pack,
    sentAt: sentAt,
    read: read ?? this.read,
    reminderKey: reminderKey,
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
        reminderKey: json['reminder_key']?.toString(),
      );
}
