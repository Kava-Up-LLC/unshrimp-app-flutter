import 'daily_stat.dart';
import 'history_week.dart';

/// The per-day history returned by `get_stats_history`: one [DailyStat] per day
/// for the requested window (oldest first, missing days already filled with
/// zeros server-side), plus the best streak and goal-met count over it.
class StatsHistory {
  const StatsHistory({
    required this.weekCount,
    required this.dailyGoal,
    required this.bestStreak,
    required this.goalMetDays,
    required this.days,
    this.isPro = true,
  });

  /// Number of weeks the window covers (the `weeks` the function was asked for).
  final int weekCount;

  /// Whether the user is Pro. Free users get only today from the server and the
  /// weeks are blurred behind a Pro lock on screen; a missing flag defaults to
  /// Pro so an older cached payload still shows its weeks.
  final bool isPro;

  /// The user's current daily break goal, so the today card can show breaks /
  /// goal; 0 when unknown.
  final int dailyGoal;

  /// Longest run of consecutive goal-met days within the window.
  final int bestStreak;

  /// How many days in the window reached the goal.
  final int goalMetDays;

  /// Every day in the window, oldest first.
  final List<DailyStat> days;

  /// The most recent day, or null when the window is empty.
  DailyStat? get today => days.isEmpty ? null : days.last;

  /// The days grouped into weeks of seven, newest week first, each week's days
  /// kept oldest-left. A trailing partial group (when days isn't a multiple of
  /// seven) becomes its own shorter week.
  List<HistoryWeek> get weeks {
    final result = <HistoryWeek>[];
    for (var start = 0; start < days.length; start += 7) {
      final end = (start + 7 <= days.length) ? start + 7 : days.length;
      result.add(HistoryWeek(days.sublist(start, end)));
    }
    return result.reversed.toList();
  }

  /// The weeks worth showing, newest first: [weeks] minus those where nothing
  /// happened all seven days, so the screen never renders a row of empty days.
  List<HistoryWeek> get activeWeeks =>
      weeks.where((w) => w.hasActivity).toList();

  factory StatsHistory.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) => (value as num?)?.toInt() ?? 0;
    final rawDays = json['days'];
    return StatsHistory(
      weekCount: asInt(json['weeks']),
      dailyGoal: asInt(json['daily_goal']),
      bestStreak: asInt(json['best_streak']),
      goalMetDays: asInt(json['goal_met_days']),
      isPro: json['is_pro'] is bool ? json['is_pro'] as bool : true,
      days: rawDays is List
          ? rawDays
                .whereType<Map<String, dynamic>>()
                .map(DailyStat.fromJson)
                .toList()
          : const [],
    );
  }
}
