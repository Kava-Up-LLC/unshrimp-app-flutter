/// A reminder handed to the OS, remembered on the device so the app can tell
/// later which ones were shown. Either daily at [hour]:[minute], or once at
/// [at].
class ScheduledReminder {
  const ScheduledReminder.daily({
    required this.key,
    required int this.hour,
    required int this.minute,
    required this.body,
    required this.pack,
    required this.scheduledAt,
  }) : at = null;

  const ScheduledReminder.once({
    required this.key,
    required DateTime this.at,
    required this.body,
    required this.pack,
    required this.scheduledAt,
  }) : hour = null,
       minute = null;

  /// Identifies this reminder in its notification payload and its
  /// `notifications` rows. Null for records saved before keys existed.
  final String? key;

  final int? hour;
  final int? minute;

  /// Fire time of a one-off reminder (the debug one); null for daily ones.
  final DateTime? at;
  final String body;
  final String pack;

  /// When it was handed to the OS: nothing fires before this.
  final DateTime scheduledAt;

  bool get isDaily => at == null;

  Map<String, Object?> toJson() => {
    'key': key,
    'hour': hour,
    'minute': minute,
    'at': at?.toUtc().toIso8601String(),
    'body': body,
    'pack': pack,
    'scheduled_at': scheduledAt.toUtc().toIso8601String(),
  };

  factory ScheduledReminder.fromJson(Map<String, dynamic> json) {
    final scheduledAt = DateTime.parse(json['scheduled_at'] as String);
    final body = json['body'] as String;
    final pack = json['pack'] as String;
    final key = json['key'] as String?;
    final at = json['at'] as String?;
    return at != null
        ? ScheduledReminder.once(
            key: key,
            at: DateTime.parse(at),
            body: body,
            pack: pack,
            scheduledAt: scheduledAt,
          )
        : ScheduledReminder.daily(
            key: key,
            hour: json['hour'] as int,
            minute: json['minute'] as int,
            body: body,
            pack: pack,
            scheduledAt: scheduledAt,
          );
  }
}
