import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/event_log.dart';
import '../../auth/repositories/token_storage.dart';
import '../../exercises/repositories/exercises_repository.dart';
import '../../notifications/services/reminder_opened_marker.dart';
import '../../settings/repositories/settings_repository.dart';
import '../models/break_args.dart';
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

/// The 60 s micro-break. Tracks `break_started` when opened and
/// `break_completed` only when the countdown reaches 0; leaving earlier
/// disposes the countdown and tracks nothing more.
class BreakViewModel extends AsyncNotifier<BreakState> {
  BreakViewModel(this.args);

  final BreakArgs args;
  StreamSubscription<void>? _ticks;

  @override
  Future<BreakState> build() async {
    ref.onDispose(() => _ticks?.cancel());
    _track('break_started', args.zone);

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

    _ticks = ref.read(breakTicksProvider)().listen((_) => _tick());
    return BreakState(
      exercise: exercise,
      zone: zone,
      secondsLeft: BreakState.totalSeconds,
    );
  }

  void _tick() {
    final current = state.value;
    if (current == null || current.isCompleted) return;

    final secondsLeft = current.secondsLeft - 1;
    state = AsyncData(current.copyWith(secondsLeft: max(secondsLeft, 0)));
    if (secondsLeft <= 0) {
      _ticks?.cancel();
      _track('break_completed', current.zone);
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
