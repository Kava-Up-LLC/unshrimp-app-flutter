import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../shared/widgets/submit_button.dart';
import '../view_models/reminder_permission_view_model.dart';

/// Shown once before Home: explains why Unshrimp needs notifications, then
/// hands over to the OS prompt.
class ReminderPermissionView extends ConsumerWidget {
  const ReminderPermissionView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reminderPermissionViewModelProvider);
    final viewModel = ref.read(reminderPermissionViewModelProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    ref.listen(reminderPermissionViewModelProvider, (_, next) {
      if (next.isDone) context.go(AppRoutes.home);
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                Icons.notifications_active_outlined,
                size: 72,
                color: colors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Let Unshrimp nag you',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your reminders to sit up and take a break are notifications. '
                'They arrive during your active hours, even when the app is '
                'closed, and never while reminders are paused.',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              SubmitButton(
                label: 'Turn on reminders',
                isLoading: state.isBusy,
                onPressed: viewModel.allow,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: state.isBusy ? null : viewModel.skip,
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
