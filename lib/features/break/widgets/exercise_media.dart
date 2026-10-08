import 'package:flutter/material.dart';

import '../../exercises/models/exercise.dart';

/// The exercise's gif or image in a rounded frame: the CMS media, falling
/// back to the bundled copy when it's missing or can't be loaded.
class ExerciseMedia extends StatelessWidget {
  const ExerciseMedia({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = Icon(
      Icons.accessibility_new,
      size: 96,
      color: colors.primary,
    );
    final bundled = exercise.assetPath != null
        ? Image.asset(exercise.assetPath!, fit: BoxFit.contain)
        : placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(
        color: colors.surfaceContainerHighest,
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Center(
            child: exercise.mediaUrl != null
                ? Image.network(
                    exercise.mediaUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => bundled,
                    // Show progress while the CMS media downloads instead of a
                    // blank frame that looks broken.
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                        ? child
                        : const Center(child: CircularProgressIndicator()),
                  )
                : bundled,
          ),
        ),
      ),
    );
  }
}
