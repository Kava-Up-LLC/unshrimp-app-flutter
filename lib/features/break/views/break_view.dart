import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../subscriptions/widgets/pro_lock_tile.dart';
import '../models/break_args.dart';
import '../models/break_phase.dart';
import '../models/break_state.dart';
import '../view_models/break_view_model.dart';
import '../widgets/count_in_overlay.dart';
import '../widgets/countdown_ring.dart';
import '../widgets/exercise_media.dart';

/// Human label for a pain zone in the lock copy.
const _zoneLabels = {
  'neck': 'neck',
  'shoulders': 'shoulders',
  'lower_back': 'lower back',
  'wrists': 'wrists',
  'none': 'posture',
};

/// The 60 s micro-break: one stretch for the user's pain zone, a "Start" that
/// kicks off a 3-2-1 count-in and the countdown, then "Survived" at 0.
class BreakView extends ConsumerWidget {
  const BreakView({super.key, required this.args});

  final BreakArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakState = ref.watch(breakViewModelProvider(args));

    return Scaffold(
      appBar: AppBar(title: const Text('Micro-break')),
      body: SafeArea(
        child: switch (breakState) {
          AsyncData(:final value) => _BreakContent(
            state: value,
            onStart: () =>
                ref.read(breakViewModelProvider(args).notifier).start(),
            onSurvived: () async {
              await ref
                  .read(breakViewModelProvider(args).notifier)
                  .registerBreak();
              if (context.mounted) context.go(AppRoutes.home);
            },
          ),
          AsyncError() => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Couldn't load the break."),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _BreakContent extends StatelessWidget {
  const _BreakContent({
    required this.state,
    required this.onStart,
    required this.onSurvived,
  });

  final BreakState state;
  final VoidCallback onStart;
  final VoidCallback onSurvived;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Stack(
          children: [
            ExerciseMedia(exercise: state.exercise),
            if (state.phase == BreakPhase.countingIn)
              CountInOverlay(count: state.countInLeft),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          state.exercise.title,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          state.exercise.steps,
          style: textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
        ),
        if (!state.isPro && state.hasLockedPro) ...[
          const SizedBox(height: 16),
          ProLockTile(
            label:
                'More exercises for your ${_zoneLabels[state.zone] ?? 'posture'}',
            onTap: () => context.push(AppRoutes.pro),
          ),
        ],
        const SizedBox(height: 28),
        Center(
          child: CountdownRing(
            secondsLeft: state.secondsLeft,
            progress: state.progress,
          ),
        ),
        const SizedBox(height: 28),
        if (state.phase == BreakPhase.ready)
          FilledButton(onPressed: onStart, child: const Text('Start'))
        else
          FilledButton(
            onPressed: state.isCompleted ? onSurvived : null,
            child: const Text('Survived'),
          ),
      ],
    );
  }
}
