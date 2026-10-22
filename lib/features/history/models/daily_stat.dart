import 'day_status.dart';

/// One day of the per-user history, as returned by `get_stats_history`.
class DailyStat {
  const DailyStat({
    required this.day,
    required this.breaks,
    required this.ignored,
    required this.goalMet,
    this.rest = false,
  });

  /// The user's local calendar day, "YYYY-MM-DD".
  final String day;
  final int breaks;
  final int ignored;
  final bool goalMet;

  /// A day the user does not work (from active_days): shown as rest and skipped
  /// by the streak, server-side.
  final bool rest;

  /// rest when it is a day off, otherwise met / partial / missed by the breaks
  /// against the goal.
  DayStatus get status => rest
      ? DayStatus.rest
      : goalMet
      ? DayStatus.met
      : (breaks > 0 ? DayStatus.partial : DayStatus.missed);

  factory DailyStat.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) => (value as num?)?.toInt() ?? 0;
    return DailyStat(
      day: json['day']?.toString() ?? '',
      breaks: asInt(json['breaks']),
      ignored: asInt(json['ignored']),
      goalMet: asInt(json['goal_met']) != 0,
      rest: asInt(json['rest']) != 0,
    );
  }
}
