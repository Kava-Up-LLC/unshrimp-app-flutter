/// The `user_settings` row seeded by `save_onboarding`, plus the archetype it
/// wrote to `user_stats`.
class SeededSettings {
  const SeededSettings({
    required this.userId,
    required this.activeStart,
    required this.activeEnd,
    required this.reminderIntervalMin,
    required this.graceWindowMin,
    required this.dailyGoal,
    required this.roastThreshold,
    required this.painZone,
    required this.quietMode,
    required this.pausedUntil,
    required this.archetype,
  });

  final int userId;
  final String activeStart;
  final String activeEnd;
  final int reminderIntervalMin;
  final int graceWindowMin;
  final int dailyGoal;
  final int roastThreshold;
  final String painZone;
  final bool quietMode;
  final String? pausedUntil;
  final String archetype;

  factory SeededSettings.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) => (value as num?)?.toInt() ?? 0;

    return SeededSettings(
      userId: asInt(json['user_id']),
      activeStart: json['active_start']?.toString() ?? '',
      activeEnd: json['active_end']?.toString() ?? '',
      reminderIntervalMin: asInt(json['reminder_interval_min']),
      graceWindowMin: asInt(json['grace_window_min']),
      dailyGoal: asInt(json['daily_goal']),
      roastThreshold: asInt(json['roast_threshold']),
      painZone: json['pain_zone']?.toString() ?? '',
      quietMode: json['quiet_mode'] == true,
      pausedUntil: json['paused_until']?.toString(),
      archetype: json['archetype']?.toString() ?? '',
    );
  }
}
