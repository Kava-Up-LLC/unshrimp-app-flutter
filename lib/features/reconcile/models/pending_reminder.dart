/// A reminder that was delivered but not yet opened or reconciled, as returned
/// by `get_pending_reminders`.
class PendingReminder {
  const PendingReminder({
    required this.id,
    required this.sentAtUtc,
    this.reminderKey,
  });

  final int id;

  /// When the reminder was sent, as a UTC instant. `get_pending_reminders`
  /// sends ISO-8601 UTC so this parses to an instant, not a local time.
  final DateTime sentAtUtc;

  final String? reminderKey;

  factory PendingReminder.fromJson(Map<String, dynamic> json) => PendingReminder(
    id: (json['id'] as num).toInt(),
    sentAtUtc:
        DateTime.tryParse(json['sent_at']?.toString() ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    reminderKey: json['reminder_key']?.toString(),
  );
}
