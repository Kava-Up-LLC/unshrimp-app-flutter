import 'package:flutter/material.dart';

import '../models/daily_stat.dart';
import '../models/day_status.dart';

/// One day in a week: the day-of-month, a bar that fills toward the daily goal
/// (teal when met, amber when partial, empty track when missed), and the day's
/// `breaks / goal` with a check once the goal is reached.
class DayRow extends StatelessWidget {
  const DayRow({super.key, required this.stat, required this.dailyGoal});

  final DailyStat stat;
  final int dailyGoal;

  static const _barHeight = 10.0;

  /// The day-of-month ("Oct 10" -> "10") for a "YYYY-MM-DD" day; safe offline.
  String get _dayOfMonth {
    final parts = stat.day.split('-');
    if (parts.length != 3) return stat.day;
    return (int.tryParse(parts[2]) ?? 0).toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // A rest day: no bar and no count — the user does not work this day, so it
    // reads as rest rather than a missed goal.
    if (stat.status == DayStatus.rest) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                _dayOfMonth,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.bedtime_outlined, size: 14, color: colors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              'Rest day',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    final goal = dailyGoal > 0 ? dailyGoal : stat.breaks;
    final fraction = goal > 0 ? (stat.breaks / goal).clamp(0.0, 1.0) : 0.0;
    final fill = switch (stat.status) {
      DayStatus.met => colors.primary,
      DayStatus.partial => colors.tertiary,
      DayStatus.missed => Colors.transparent,
      DayStatus.rest => Colors.transparent,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              _dayOfMonth,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_barHeight / 2),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: _barHeight,
                backgroundColor: colors.surfaceContainerHighest,
                color: fill,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${stat.breaks}/$goal',
            style: theme.textTheme.bodyMedium,
          ),
          SizedBox(
            width: 20,
            child: stat.goalMet
                ? Icon(Icons.check_circle, size: 16, color: colors.primary)
                : null,
          ),
        ],
      ),
    );
  }
}
