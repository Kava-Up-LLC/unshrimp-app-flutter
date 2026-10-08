import '../../exercises/models/exercise.dart';
import 'break_phase.dart';

/// A micro-break: the stretch, its phase, and the countdown.
class BreakState {
  const BreakState({
    required this.exercise,
    required this.zone,
    required this.phase,
    required this.secondsLeft,
    required this.countInLeft,
  });

  static const totalSeconds = 60;

  /// The 3, 2, 1 count-in before the 60 s begins.
  static const countInSeconds = 3;

  final Exercise exercise;

  /// Pain zone the stretch was picked for.
  final String zone;

  final BreakPhase phase;
  final int secondsLeft;

  /// 3, 2, 1 during [BreakPhase.countingIn]; unused otherwise.
  final int countInLeft;

  /// The countdown reached 0: "Survived" is enabled.
  bool get isCompleted => phase == BreakPhase.done;

  double get progress => secondsLeft / totalSeconds;

  BreakState copyWith({
    BreakPhase? phase,
    int? secondsLeft,
    int? countInLeft,
  }) => BreakState(
    exercise: exercise,
    zone: zone,
    phase: phase ?? this.phase,
    secondsLeft: secondsLeft ?? this.secondsLeft,
    countInLeft: countInLeft ?? this.countInLeft,
  );
}
