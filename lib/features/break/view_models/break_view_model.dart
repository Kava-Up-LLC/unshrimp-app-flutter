import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/event_log.dart';
import '../../auth/models/auth_exception.dart';
import '../../auth/repositories/token_storage.dart';
import '../../exercises/repositories/exercises_repository.dart';
import '../../home/repositories/home_repository.dart';
import '../../home/view_models/home_view_model.dart';
import '../../notifications/services/reminder_opened_marker.dart';
import '../../settings/repositories/settings_repository.dart';
import '../models/break_args.dart';
import '../models/break_phase.dart';
import '../models/break_source.dart';
import '../models/break_state.dart';
import '../services/exercise_picker.dart';

/// Makes the countdown's one-second ticks. A factory, not a stream: each
/// break needs its own single-subscription stream. Overridden in tests.
final breakTicksProvider = Provider<Stream<void> Function()>(
  (ref) =>
      () => Stream<void>.periodic(const Duration(seconds: 1)),
);

final breakViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<BreakViewModel, BreakState, BreakArgs>(
      BreakViewModel.new,
      retry: (_, _) => null,
    );

/// The 60 s micro-break. Opens showing the stretch at 60 with nothing ticking
/// and no analytics; [start] tracks `break_started`, runs the 3-2-1 count-in,
/// then the countdown. `break_completed` fires only when it reaches 0; leaving
/// earlier disposes the countdown and tracks nothing more.
class BreakViewModel extends AsyncNotifier<BreakState> {
  BreakViewModel(this.args);

  final BreakArgs args;
  StreamSubscription<void>? _ticks;

  @override
  Future<BreakState> build() async {
    ref.onDispose(() => _ticks?.cancel());

    // Opened from a reminder: mark its notification read (in the background,
    // the break doesn't wait).
    final reminderKey = args.reminderKey;
    if (args.source == BreakSource.reminder && reminderKey != null) {
      unawaited(ref.read(reminderOpenedMarkerProvider).markOpened(reminderKey));
    }

    final zone = args.zone ?? await _zoneFromSettings();
    final exercises = await ref
        .read(exercisesRepositoryProvider)
        .fetchExercises();
    final exercise = pickExercise(exercises, zone, Random());

    return BreakState(
      exercise: exercise,
      zone: zone,
      phase: BreakPhase.ready,
      secondsLeft: BreakState.totalSeconds,
      countInLeft: BreakState.countInSeconds,
    );
  }

  /// The user tapped "Start": track `break_started`, begin the 3-2-1 count-in,
  /// and wire up the one-second ticks that drive it and the countdown.
  void start() {
    final current = state.value;
    if (current == null || current.phase != BreakPhase.ready) return;

    _track('break_started', current.zone);
    state = AsyncData(
      current.copyWith(
        phase: BreakPhase.countingIn,
        countInLeft: BreakState.countInSeconds,
      ),
    );
    _ticks = ref.read(breakTicksProvider)().listen((_) => _tick());
  }

  void _tick() {
    final current = state.value;
    if (current == null) return;

    switch (current.phase) {
      case BreakPhase.countingIn:
        final countInLeft = current.countInLeft - 1;
        if (countInLeft <= 0) {
          state = AsyncData(
            current.copyWith(
              phase: BreakPhase.running,
              secondsLeft: BreakState.totalSeconds,
            ),
          );
        } else {
          state = AsyncData(current.copyWith(countInLeft: countInLeft));
        }
      case BreakPhase.running:
        final secondsLeft = current.secondsLeft - 1;
        if (secondsLeft <= 0) {
          _ticks?.cancel();
          state = AsyncData(
            current.copyWith(phase: BreakPhase.done, secondsLeft: 0),
          );
          _track('break_completed', current.zone);
        } else {
          state = AsyncData(current.copyWith(secondsLeft: secondsLeft));
        }
      case BreakPhase.ready:
      case BreakPhase.done:
        return;
    }
  }

  /// Reports the completed break to the server (`register_break`) and pushes
  /// the returned row into Home. Called once, when the user taps "Survived" at
  /// 0. Best-effort: the break already happened, and Home re-fetches on mount,
  /// so a failure here just means Home shows the fresh row (or an expired
  /// session) a moment later instead of instantly.
  Future<void> registerBreak() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;
    try {
      final stats = await ref.read(homeRepositoryProvider).registerBreak(token);
      ref.read(homeViewModelProvider.notifier).applyStats(stats);
    } on AuthException {
      // Swallowed on purpose: see the doc comment above.
    }
  }

  /// The user's `pain_zone`, or [generalZone] when it can't be read.
  Future<String> _zoneFromSettings() async {
    try {
      final token = await ref.read(tokenStorageProvider).read();
      if (token != null) {
        final zone =
            (await ref.read(settingsRepositoryProvider).fetch(token)).painZone;
        if (zone.isNotEmpty) return zone;
      }
    } on Exception {
      // Offline or no settings yet: a general stretch still works.
    }
    return generalZone;
  }

  void _track(String event, String? zone) => ref.read(eventLogProvider).log(
    event,
    {'source': args.source.name, 'zone': ?zone},
  );
}
