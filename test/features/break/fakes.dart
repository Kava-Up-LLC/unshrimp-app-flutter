import 'package:unshrimp_app/features/exercises/models/exercise.dart';
import 'package:unshrimp_app/features/exercises/repositories/exercises_repository.dart';

const neckStretch = Exercise(
  zone: 'neck',
  title: 'Chin Tuck Hold',
  steps: 'Pull your chin straight back.',
);

const generalStretch = Exercise(
  zone: 'none',
  title: 'Mountain Pose',
  steps: 'Stand tall.',
);

class FakeExercisesRepository implements ExercisesRepository {
  const FakeExercisesRepository([
    this.exercises = const [neckStretch, generalStretch],
  ]);

  final List<Exercise> exercises;

  @override
  Future<List<Exercise>> fetchExercises() async => exercises;
}
