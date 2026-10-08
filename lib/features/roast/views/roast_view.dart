import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../break/models/break_args.dart';
import '../../break/models/break_source.dart';
import '../../home/widgets/spine_battery_card.dart';
import '../view_models/roast_gate_provider.dart';
import '../view_models/roast_view_model.dart';

/// Full-screen Posture Roast, shown while `roast_pending` is true. The only way
/// out is the 60 s break ("Fix my posture"); there is no dismiss.
class RoastView extends ConsumerWidget {
  const RoastView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final line = ref.watch(roastViewModelProvider).value ?? '';
    final roastLevel = ref.watch(roastGateProvider).roastLevel;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.coralContainerDark,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: Image.asset(
                    'assets/images/shrimp_hurt.png',
                    width: 180,
                    height: 180,
                    // The hurt-shrimp art is produced separately; until it
                    // lands, hold the layout instead of crashing on the
                    // missing asset.
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(width: 180, height: 180),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  line,
                  textAlign: TextAlign.center,
                  // White passes AA on coralContainerDark (#7A2A18, ~9.67:1).
                  style: textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 28),
                SpineBatteryCard(roastLevel: roastLevel),
                const Spacer(),
                FilledButton(
                  onPressed: () =>
                      context.go(const BreakArgs(source: BreakSource.roast).location),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.textLight,
                  ),
                  child: const Text('Fix my posture'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(roastViewModelProvider.notifier).share(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                  ),
                  child: const Text('Share my shame'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
