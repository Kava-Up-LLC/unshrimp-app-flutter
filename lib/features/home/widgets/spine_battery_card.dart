import 'package:flutter/material.dart';

import '../models/user_stats.dart';

/// Spine Battery: a battery that drains with every ignored reminder and
/// recharges with every completed break. Reads `roastLevel` (0 to 5) and shows
/// it as charge (`5 - roastLevel`). A real battery silhouette on a coral
/// container (DESIGN.md), with a charge colour that tracks the level: teal at
/// 100/80, amber at 60/40, coral at 20, error red at 0.
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

  /// Charge colour per the level (charge is `5 - roastLevel`, i.e. 5 = 100%).
  static Color _chargeColor(ColorScheme colors, int charge) {
    if (charge >= 4) return colors.primary; // 100% / 80% -> teal
    if (charge >= 2) return colors.tertiary; // 60% / 40% -> amber
    if (charge >= 1) return colors.secondary; // 20% -> coral
    return colors.error; // 0% -> error red
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final level = roastLevel.clamp(0, UserStats.maxRoastLevel);
    final charge = UserStats.maxRoastLevel - level;
    final fill = _chargeColor(colors, charge);

    return Container(
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
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
                    color: colors.onSecondaryContainer,
                  ),
                ),
              ),
              Text(
                '${charge * 20}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: fill,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _BatterySilhouette(charge: charge, fill: fill),
          const SizedBox(height: 12),
          Text(
            _labels[charge],
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// The battery drawing: a bordered body with five cells, plus the terminal nub.
/// Each cell animates its colour (~300 ms) as the charge changes, so the cell
/// that goes out fades from the charge colour to empty.
class _BatterySilhouette extends StatelessWidget {
  const _BatterySilhouette({required this.charge, required this.fill});

  final int charge;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final outline = colors.onSecondaryContainer.withValues(alpha: 0.45);
    final empty = colors.onSecondaryContainer.withValues(alpha: 0.15);

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              border: Border.all(color: outline, width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                for (
                  var segment = 1;
                  segment <= UserStats.maxRoastLevel;
                  segment++
                ) ...[
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: segment <= charge ? fill : empty,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  if (segment < UserStats.maxRoastLevel)
                    const SizedBox(width: 5),
                ],
              ],
            ),
          ),
        ),
        Container(
          width: 5,
          height: 18,
          margin: const EdgeInsets.only(left: 3),
          decoration: BoxDecoration(
            color: outline,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(3),
            ),
          ),
        ),
      ],
    );
  }
}
