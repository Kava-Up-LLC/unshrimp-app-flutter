import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../models/break_args.dart';
import '../models/break_state.dart';
import '../view_models/break_view_model.dart';
import '../widgets/countdown_ring.dart';
import '../widgets/exercise_media.dart';

/// The 60 s micro-break: one stretch for the user's pain zone, a countdown,
/// and "Survived" once it reaches 0.
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
            onSurvived: () => context.go(AppRoutes.home),
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
  const _BreakContent({required this.state, required this.onSurvived});

  final BreakState state;
  final VoidCallback onSurvived;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ExerciseMedia(exercise: state.exercise),
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
        const SizedBox(height: 28),
        Center(
          child: CountdownRing(
            secondsLeft: state.secondsLeft,
            progress: state.progress,
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: state.isCompleted ? onSurvived : null,
          child: const Text('Survived'),
        ),
      ],
    );
  }
}
