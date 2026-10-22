import 'package:flutter/material.dart';

/// A lock where a Pro feature lives — a row, not a wall. Shows a lock icon, the
/// [label], and a "Pro" tag; tapping opens the Pro screen.
class ProLockTile extends StatelessWidget {
  const ProLockTile({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 20, color: colors.secondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: textTheme.bodyMedium),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Pro',
                style: textTheme.labelSmall?.copyWith(
                  color: colors.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
