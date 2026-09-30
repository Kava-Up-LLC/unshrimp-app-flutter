import '../../exercises/models/exercise.dart';

/// A running micro-break: the stretch and the countdown.
class BreakState {
  const BreakState({
    required this.exercise,
    required this.zone,
    required this.secondsLeft,
  });

  static const totalSeconds = 60;

  final Exercise exercise;

  /// Pain zone the stretch was picked for.
  final String zone;
  final int secondsLeft;

  /// The countdown reached 0: "Survived" is enabled.
  bool get isCompleted => secondsLeft == 0;

  double get progress => secondsLeft / totalSeconds;

  BreakState copyWith({int? secondsLeft}) => BreakState(
    exercise: exercise,
    zone: zone,
    secondsLeft: secondsLeft ?? this.secondsLeft,
  );
}
