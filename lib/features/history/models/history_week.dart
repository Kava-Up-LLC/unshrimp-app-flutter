import 'daily_stat.dart';

/// One week's strip of days, oldest on the left. Built by [StatsHistory] from a
/// run of seven consecutive [DailyStat]s.
class HistoryWeek {
  const HistoryWeek(this.days);

  final List<DailyStat> days;

  /// Ignored reminders across the week — the "ignored this week" caption.
  int get ignored => days.fold(0, (sum, d) => sum + d.ignored);

  /// Whether anything happened this week — a break taken or a reminder ignored
  /// on at least one day. Weeks with no activity are hidden on the History
  /// screen so it never shows a row of empty days.
  bool get hasActivity => days.any((d) => d.breaks > 0 || d.ignored > 0);
}
