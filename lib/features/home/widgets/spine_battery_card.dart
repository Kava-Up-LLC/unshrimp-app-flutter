import 'package:flutter/material.dart';

import '../models/user_stats.dart';

/// Spine Battery: a battery that drains with every ignored reminder and
/// recharges with every completed break. Reads `roastLevel` (0 to 5) and shows
/// it as charge (`5 - roastLevel`). Coral = the roast side of the app.
class SpineBatteryCard extends StatelessWidget {
  const SpineBatteryCard({super.key, required this.roastLevel});

  final int roastLevel;

  static const _labels = [
    'Dead. Stretch to recharge.',
    'Critical',
    'Low battery',
    'Getting low',
    'Running fine',
    'Fully charged',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final level = roastLevel.clamp(0, UserStats.maxRoastLevel);
    final charge = UserStats.maxRoastLevel - level;

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
                    'Spine Battery',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  '${charge * 20}%',
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
                        color: segment <= charge
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
            Text(_labels[charge], style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
