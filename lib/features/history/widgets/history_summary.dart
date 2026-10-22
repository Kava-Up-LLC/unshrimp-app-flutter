import 'package:flutter/material.dart';

/// Best streak (amber, the achievement colour) and days-goal-met over the
/// window, side by side.
class HistorySummary extends StatelessWidget {
  const HistorySummary({
    super.key,
    required this.bestStreak,
    required this.goalMetDays,
  });

  final int bestStreak;
  final int goalMetDays;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _Tile(
            icon: Icons.local_fire_department,
            color: colors.tertiary,
            value: '$bestStreak',
            label: bestStreak == 1 ? 'best streak (day)' : 'best streak (days)',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _Tile(
            icon: Icons.emoji_events_outlined,
            color: colors.primary,
            value: '$goalMetDays',
            label: goalMetDays == 1 ? 'day goal met' : 'days goal met',
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
