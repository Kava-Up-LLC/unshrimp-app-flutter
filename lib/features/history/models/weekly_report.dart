/// The weekly Spine Report returned by `get_weekly_report`: the four numbers of
/// the last complete week, the delta against the week before, and the spine's
/// verdict. [locked] is a Free stub (`{locked: true}`) with no numbers — the
/// card blurs it behind a Pro lock.
class WeeklyReport {
  const WeeklyReport({
    required this.locked,
    this.weekStart,
    this.breaks = 0,
    this.ignored = 0,
    this.bestDay,
    this.longestStreak = 0,
    this.breaksDelta = 0,
    this.verdict,
  });

  /// The Free stub: no data, shown blurred behind a Pro lock.
  const WeeklyReport.locked()
    : locked = true,
      weekStart = null,
      breaks = 0,
      ignored = 0,
      bestDay = null,
      longestStreak = 0,
      breaksDelta = 0,
      verdict = null;

  /// Whether this is the Free locked stub.
  final bool locked;

  /// Monday of the last complete week.
  final DateTime? weekStart;

  final int breaks;
  final int ignored;

  /// The day with the most breaks, or null when the week had no breaks.
  final DateTime? bestDay;

  /// Longest run of consecutive goal-met days within the week.
  final int longestStreak;

  /// This week's breaks minus the week before's (positive = more breaks).
  final int breaksDelta;

  /// The spine's verdict for the week, already with `{ignored}` filled in.
  final String? verdict;

  factory WeeklyReport.fromJson(Map<String, dynamic> json) {
    if (json['locked'] == true) return const WeeklyReport.locked();
    int asInt(Object? value) => (value as num?)?.toInt() ?? 0;
    return WeeklyReport(
      locked: false,
      weekStart: DateTime.tryParse(json['week_start']?.toString() ?? ''),
      breaks: asInt(json['breaks']),
      ignored: asInt(json['ignored']),
      bestDay: DateTime.tryParse(json['best_day']?.toString() ?? ''),
      longestStreak: asInt(json['longest_streak']),
      breaksDelta: asInt(json['breaks_delta']),
      verdict: json['verdict']?.toString(),
    );
  }
}
