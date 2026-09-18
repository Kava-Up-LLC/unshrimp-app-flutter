import 'package:flutter/material.dart';

import '../models/user_stats.dart';

/// Camarómetro: how shrimp-like the user's posture habits are right now,
/// from 0 to 5. Coral = the roast side of the app.
class CamarometroCard extends StatelessWidget {
  const CamarometroCard({super.key, required this.roastLevel});

  final int roastLevel;

  static const _labels = [
    'Straight as a mast',
    'A slight lean',
    'Getting curvy',
    'Half shrimp',
    'Deep shrimp',
    'Full shrimp 🦐',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final level = roastLevel.clamp(0, UserStats.maxRoastLevel);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Camarómetro',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  '$level/${UserStats.maxRoastLevel}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (
                  var segment = 1;
                  segment <= UserStats.maxRoastLevel;
                  segment++
                ) ...[
                  Expanded(
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: segment <= level
                            ? colors.secondary
                            : colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  if (segment < UserStats.maxRoastLevel)
                    const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(_labels[level], style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
