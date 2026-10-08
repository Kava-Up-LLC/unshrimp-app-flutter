import 'package:flutter/material.dart';

/// The 3, 2, 1 count-in: a big centered digit over a scrim, laid on top of the
/// exercise media while the break counts in.
class CountInOverlay extends StatelessWidget {
  const CountInOverlay({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: ColoredBox(
        color: colors.scrim.withValues(alpha: 0.45),
        child: Center(
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
