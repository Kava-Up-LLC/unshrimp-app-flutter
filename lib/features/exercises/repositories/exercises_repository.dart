import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exercise.dart';
import 'fallback_exercises.dart';

/// Reads the break exercises from the CMS content type `exercises`, falling
/// back to [fallbackExercises].
class ExercisesRepository {
  const ExercisesRepository();

  static const _timeout = Duration(seconds: 10);

  Future<List<Exercise>> fetchExercises() async {
    try {
      final exercises =
          await AppAmbitCms.content('exercises', fromJson: Exercise.fromCms)
              .orderByAscending('created_at')
              .getPerPage(50)
              .getList()
              .timeout(_timeout);

      // The SDK returns an empty list when the request fails.
      if (exercises.isNotEmpty) {
        return exercises.map(_withBundledImage).toList();
      }
    } catch (_) {
      // Unreachable CMS or malformed entry: use the local copy.
    }
    return fallbackExercises;
  }

  /// Attaches the bundled image of the fallback exercise with the same title,
  /// so CMS entries without media still get their picture.
  static Exercise _withBundledImage(Exercise exercise) {
    final bundled = fallbackExercises
        .where((e) => e.title == exercise.title)
        .firstOrNull;
    return Exercise(
      zone: exercise.zone,
      title: exercise.title,
      steps: exercise.steps,
      tier: exercise.tier,
      mediaUrl: exercise.mediaUrl,
      assetPath: bundled?.assetPath,
    );
  }
}

final exercisesRepositoryProvider = Provider<ExercisesRepository>(
  (ref) => const ExercisesRepository(),
);
