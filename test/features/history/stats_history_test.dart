import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/history/models/day_status.dart';
import 'package:unshrimp_app/features/history/models/stats_history.dart';

Map<String, dynamic> _day(String day, int breaks, int ignored, int goalMet) => {
  'day': day,
  'breaks': breaks,
  'ignored': ignored,
  'goal_met': goalMet,
};

Map<String, dynamic> _restDay(String day, int breaks, int goalMet) => {
  'day': day,
  'breaks': breaks,
  'ignored': 0,
  'goal_met': goalMet,
  'rest': 1,
};

void main() {
  test('groups days into weeks, newest week first, oldest day left', () {
    // 14 days, 2024-01-01 .. 2024-01-14 (oldest -> newest).
    final days = [
      for (var i = 1; i <= 14; i++)
        _day('2024-01-${i.toString().padLeft(2, '0')}', 0, 0, 0),
    ];
    final history = StatsHistory.fromJson({
      'weeks': 2,
      'best_streak': 0,
      'goal_met_days': 0,
      'days': days,
    });

    final weeks = history.weeks;
    expect(weeks.length, 2);
    expect(weeks.every((w) => w.days.length == 7), isTrue);
    // Newest week first; its last (rightmost) day is the most recent day.
    expect(weeks.first.days.last.day, '2024-01-14');
    expect(weeks.first.days.first.day, '2024-01-08');
    expect(weeks.last.days.first.day, '2024-01-01');
    // today is the newest day overall.
    expect(history.today?.day, '2024-01-14');
  });

  test('day status is met / partial / missed by breaks and goal', () {
    final history = StatsHistory.fromJson({
      'weeks': 1,
      'best_streak': 1,
      'goal_met_days': 1,
      'days': [
        _day('2024-01-01', 4, 0, 1), // goal met
        _day('2024-01-02', 2, 0, 0), // some breaks, goal not met
        _day('2024-01-03', 0, 3, 0), // no breaks
        _day('2024-01-04', 0, 0, 0),
        _day('2024-01-05', 0, 0, 0),
        _day('2024-01-06', 0, 0, 0),
        _day('2024-01-07', 0, 0, 0),
      ],
    });

    final days = history.days;
    expect(days[0].status, DayStatus.met);
    expect(days[1].status, DayStatus.partial);
    expect(days[2].status, DayStatus.missed);
    expect(history.bestStreak, 1);
    expect(history.goalMetDays, 1);
  });

  test('ignored per week sums the week days', () {
    final history = StatsHistory.fromJson({
      'weeks': 1,
      'best_streak': 0,
      'goal_met_days': 0,
      'days': [
        _day('2024-01-01', 0, 2, 0),
        _day('2024-01-02', 0, 1, 0),
        _day('2024-01-03', 0, 0, 0),
        _day('2024-01-04', 0, 0, 0),
        _day('2024-01-05', 0, 0, 0),
        _day('2024-01-06', 0, 0, 0),
        _day('2024-01-07', 0, 3, 0),
      ],
    });
    expect(history.weeks.single.ignored, 6);
  });

  test('a rest day reads as rest, regardless of breaks', () {
    final history = StatsHistory.fromJson({
      'weeks': 1,
      'best_streak': 0,
      'goal_met_days': 0,
      'days': [
        _restDay('2024-01-01', 5, 1), // met numbers, but a rest day
        _day('2024-01-02', 4, 0, 1),
      ],
    });

    expect(history.days[0].rest, isTrue);
    expect(history.days[0].status, DayStatus.rest); // rest wins over met
    expect(history.days[1].status, DayStatus.met);
  });

  test('activeWeeks drops weeks with no breaks and no ignored', () {
    // 14 days: the older week is all zeros, the newer week has activity.
    final days = [
      for (var i = 1; i <= 7; i++)
        _day('2024-01-${i.toString().padLeft(2, '0')}', 0, 0, 0),
      _day('2024-01-08', 3, 0, 0),
      for (var i = 9; i <= 14; i++)
        _day('2024-01-${i.toString().padLeft(2, '0')}', 0, 0, 0),
    ];
    final history = StatsHistory.fromJson({
      'weeks': 2,
      'best_streak': 0,
      'goal_met_days': 0,
      'days': days,
    });

    expect(history.weeks.length, 2);
    // Only the week that had a break survives; it keeps its 7 days.
    expect(history.activeWeeks.length, 1);
    expect(history.activeWeeks.single.days.last.day, '2024-01-14');
  });

  test('a week with only ignored reminders still counts as active', () {
    final history = StatsHistory.fromJson({
      'weeks': 1,
      'best_streak': 0,
      'goal_met_days': 0,
      'days': [
        _day('2024-01-01', 0, 2, 0),
        for (var i = 2; i <= 7; i++)
          _day('2024-01-0$i', 0, 0, 0),
      ],
    });

    expect(history.weeks.single.hasActivity, isTrue);
    expect(history.activeWeeks.length, 1);
  });
}
