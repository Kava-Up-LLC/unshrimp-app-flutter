import 'package:flutter/material.dart';

/// Today's status: breaks taken against the daily goal. Teal = health.
class BreaksTodayCard extends StatelessWidget {
  const BreaksTodayCard({
    super.key,
    required this.breaksToday,
    required this.dailyGoal,
  });

  final int breaksToday;
  final int dailyGoal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final breaks = breaksToday == 1 ? 'break' : 'breaks';
    // Show progress toward the goal when we know it; otherwise just the count.
    final value = dailyGoal > 0
        ? '$breaksToday of $dailyGoal'
        : '$breaksToday $breaks';

    return Card(
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
                      color: colors.onSurfaceVariant,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
