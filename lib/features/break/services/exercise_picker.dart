import 'dart:math';

import '../../exercises/models/exercise.dart';

/// Zone of the general stretches, used when a zone has none of its own.
const generalZone = 'none';

/// The stretches shown for [zone]: that zone's, else [generalZone]'s, else all.
/// [exercises] must not be empty, so the result never is. The list arrives
/// ordered by `created_at`, so `.first` is the first in CMS order.
List<Exercise> zoneCandidates(List<Exercise> exercises, String zone) {
  List<Exercise> ofZone(String zone) =>
      exercises.where((exercise) => exercise.zone == zone).toList();

  return [
    ofZone(zone),
    ofZone(generalZone),
    exercises,
  ].firstWhere((list) => list.isNotEmpty);
}

/// One stretch for [zone] (see [zoneCandidates]). Pro gets a random one of the
/// zone's stretches; Free gets a random one of its `free`-tier stretches, or the
/// first stretch of the zone when it has none — so Free always gets one.
Exercise pickExercise(
  List<Exercise> exercises,
  String zone, {
  required bool isPro,
  Random? random,
}) {
  final candidates = zoneCandidates(exercises, zone);
  final rng = random ?? Random();
  if (isPro) return candidates[rng.nextInt(candidates.length)];
  final free = candidates.where((e) => e.tier == 'free').toList();
  final pool = free.isEmpty ? [candidates.first] : free;
  return pool[rng.nextInt(pool.length)];
}
