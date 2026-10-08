/// The logged-in user's progress, as returned by `get_user_stats`.
class UserStats {
  const UserStats({
    required this.userId,
    required this.name,
    required this.archetype,
    required this.currentStreak,
    required this.breaksToday,
    required this.ignoredCount,
    required this.roastLevel,
    required this.roastPending,
  });

  /// Highest roast level; a fully drained Spine Battery (0% charge).
  static const maxRoastLevel = 5;

  /// Spine Battery charge as a percent: full at roast level 0, empty at 5.
  int get batteryPercent => (maxRoastLevel - roastLevel.clamp(0, maxRoastLevel)) * 20;

  final int userId;
  final String name;
  final String? archetype;
  final int currentStreak;
  final int breaksToday;
  final int ignoredCount;
  final int roastLevel;
  final bool roastPending;

  factory UserStats.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) => (value as num?)?.toInt() ?? 0;

    return UserStats(
      userId: asInt(json['user_id']),
      name: json['name']?.toString() ?? '',
      archetype: json['archetype']?.toString(),
      currentStreak: asInt(json['current_streak']),
      breaksToday: asInt(json['breaks_today']),
      ignoredCount: asInt(json['ignored_count']),
      roastLevel: asInt(json['roast_level']),
      roastPending: json['roast_pending'] == true,
    );
  }
}
