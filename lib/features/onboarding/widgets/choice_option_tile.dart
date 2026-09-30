import 'package:flutter/material.dart';

/// Tappable answer of a single-choice question: tinted with a 2px [accent]
/// border and a filled check when selected, outlined with an empty circle
/// otherwise.
class ChoiceOptionTile extends StatelessWidget {
  const ChoiceOptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.description,
  });

  final String label;
  final String? description;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(14);

    return Material(
      color: selected ? accent.withValues(alpha: 0.12) : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? accent : colors.outline,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (description case final description?)
                      Text(
                        description,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? accent : colors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
