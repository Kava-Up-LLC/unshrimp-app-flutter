/// The logged-in user's `user_settings` row, as returned by `get_settings`
/// and `update_settings`.
class UserSettings {
  const UserSettings({
    required this.activeStart,
    required this.activeEnd,
    required this.reminderIntervalMin,
    required this.graceWindowMin,
    required this.dailyGoal,
    required this.tone,
    required this.painZone,
    required this.quietMode,
    required this.pausedUntil,
  });

  /// `HH:mm` bounds of the window reminders may fire in.
  final String activeStart;
  final String activeEnd;
  final int reminderIntervalMin;

  /// Minutes after a reminder before it counts as ignored.
  final int graceWindowMin;
  final int dailyGoal;

  /// How the app treats the user: `gentle`, `direct` or `no_mercy`. Derived
  /// server-side from `roast_threshold`; the client never sends the number.
  final String tone;

  /// The `pain_zone` onboarding answer, e.g. `neck` or `none`.
  final String painZone;

  /// Reminders arrive silently for this user only.
  final bool quietMode;

  /// No reminders until this moment; null when not paused.
  final DateTime? pausedUntil;

  /// Whether a pause is still running at [now].
  bool isPausedAt(DateTime now) =>
      pausedUntil != null && pausedUntil!.isAfter(now);

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) => (value as num?)?.toInt() ?? 0;

    return UserSettings(
      activeStart: json['active_start']?.toString() ?? '',
      activeEnd: json['active_end']?.toString() ?? '',
      reminderIntervalMin: asInt(json['reminder_interval_min']),
      graceWindowMin: asInt(json['grace_window_min']),
      dailyGoal: asInt(json['daily_goal']),
      tone: json['tone']?.toString() ?? 'direct',
      painZone: json['pain_zone']?.toString() ?? '',
      quietMode: json['quiet_mode'] == true,
      pausedUntil: DateTime.tryParse(json['paused_until']?.toString() ?? ''),
    );
  }
}
