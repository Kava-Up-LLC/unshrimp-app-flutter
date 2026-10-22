import 'package:flutter/material.dart';

import '../models/history_week.dart';
import 'day_row.dart';

/// One week of history: a header with the week's date range (and the ignored
/// count when any), then one [DayRow] per day, oldest on top.
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.week, required this.dailyGoal});

  final HistoryWeek week;
  final int dailyGoal;

  /// "Jan 8" style label for a "YYYY-MM-DD" day, locale-independent and safe to
  /// render offline (no intl dependency).
  static String _short(String day) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final parts = day.split('-');
    if (parts.length != 3) return day;
    final month = int.tryParse(parts[1]) ?? 0;
    final d = int.tryParse(parts[2]) ?? 0;
    if (month < 1 || month > 12) return day;
    return '${months[month - 1]} $d';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final days = week.days;
    final range = days.isEmpty
        ? ''
        : '${_short(days.first.day)} – ${_short(days.last.day)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    range,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                if (week.ignored > 0)
                  Text(
                    '${week.ignored} ignored',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.secondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final day in days) DayRow(stat: day, dailyGoal: dailyGoal),
          ],
        ),
      ),
    );
  }
}
