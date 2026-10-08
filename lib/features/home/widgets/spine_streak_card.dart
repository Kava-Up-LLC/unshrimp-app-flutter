import 'package:flutter/material.dart';

/// Spine Streak: days in a row the user met their goal. Amber = achievement.
class SpineStreakCard extends StatelessWidget {
  const SpineStreakCard({super.key, required this.currentStreak});

  final int currentStreak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final days = currentStreak == 1 ? 'day' : 'days';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Text('🔥', style: theme.textTheme.displaySmall),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spine Streak',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$currentStreak $days',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: colors.tertiary,
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
