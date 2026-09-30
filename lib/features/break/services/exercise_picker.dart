import 'dart:math';

import '../../exercises/models/exercise.dart';

/// Zone of the general stretches, used when a zone has none of its own.
const generalZone = 'none';

/// One stretch for [zone]: a random one of that zone, else of [generalZone],
/// else of any zone. [exercises] must not be empty.
Exercise pickExercise(List<Exercise> exercises, String zone, Random random) {
  List<Exercise> ofZone(String zone) =>
      exercises.where((exercise) => exercise.zone == zone).toList();

  final candidates = [
    ofZone(zone),
    ofZone(generalZone),
    exercises,
  ].firstWhere((list) => list.isNotEmpty);
  return candidates[random.nextInt(candidates.length)];
}
