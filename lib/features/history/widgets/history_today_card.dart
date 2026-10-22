import 'package:flutter/material.dart';

import '../models/daily_stat.dart';

/// Today's status at the top of History: breaks against the goal (teal), a
/// "goal met" badge when reached, and the day's ignored count.
class HistoryTodayCard extends StatelessWidget {
  const HistoryTodayCard({
    super.key,
    required this.today,
    required this.dailyGoal,
  });

  final DailyStat today;
  final int dailyGoal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final breaksLabel = today.breaks == 1 ? 'break' : 'breaks';
    final value = dailyGoal > 0
        ? '${today.breaks} of $dailyGoal'
        : '${today.breaks} $breaksLabel';

    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.self_improvement, size: 36, color: colors.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (today.ignored > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${today.ignored} ignored',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (today.goalMet)
              Icon(Icons.check_circle, color: colors.primary, size: 28),
          ],
        ),
      ),
    );
  }
}
