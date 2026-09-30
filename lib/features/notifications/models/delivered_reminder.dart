/// A reminder the OS showed and that isn't in `notifications` yet: one row
/// for `log_notifications`.
class DeliveredReminder {
  const DeliveredReminder({
    required this.title,
    required this.body,
    required this.pack,
    required this.sentAt,
    this.reminderKey,
  });

  final String title;
  final String body;
  final String pack;
  final DateTime sentAt;

  /// Key of the scheduled reminder it came from.
  final String? reminderKey;

  Map<String, Object?> toJson() => {
    'title': title,
    'body': body,
    'pack': pack,
    'sent_at': sentAt.toUtc().toIso8601String(),
    'reminder_key': ?reminderKey,
  };

  @override
  String toString() => '$sentAt $pack: $body';
}
