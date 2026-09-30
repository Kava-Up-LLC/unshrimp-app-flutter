import 'package:flutter/material.dart';

/// The break's countdown: a ring that empties as [secondsLeft] runs out.
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    super.key,
    required this.secondsLeft,
    required this.progress,
  });

  final int secondsLeft;

  /// 1 when the countdown starts, 0 when it ends.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox.square(
      dimension: 140,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 10,
            strokeCap: StrokeCap.round,
            color: colors.primary,
            backgroundColor: colors.primaryContainer,
          ),
          Center(
            child: Text(
              secondsLeft == 0 ? 'Done' : '${secondsLeft}s',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
