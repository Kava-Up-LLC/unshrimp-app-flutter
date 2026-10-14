import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../auth/models/auth_exception.dart';
import '../../reconcile/models/reconcile_outcome.dart';
import '../../reconcile/models/reconcile_status.dart';
import '../../shared/widgets/error_banner.dart';
import '../../shared/widgets/log_out_dialog.dart';
import '../../shared/widgets/time_picker.dart';
import '../models/pause_option.dart';
import '../models/settings_options.dart';
import '../models/settings_state.dart';
import '../view_models/settings_view_model.dart';
import '../widgets/option_sheet.dart';
import '../widgets/settings_group.dart';
import '../widgets/settings_row.dart';

/// Settings: the logged-in user's `user_settings` row, editable in place.
class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsViewModelProvider);
    final viewModel = ref.read(settingsViewModelProvider.notifier);

    // A rejected token means the session is over, wherever it was rejected.
    ref.listen(settingsViewModelProvider, (_, next) {
      final error = next.error ?? next.value?.error;
      if (error is AuthException && error.code == 'INVALID_TOKEN') {
        context.go(AppRoutes.logIn);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: switch (settings) {
          AsyncData(:final value) => _SettingsContent(
            state: value,
            viewModel: viewModel,
          ),
          AsyncError(:final error) => _SettingsError(
            message: error is AuthException
                ? error.message
                : 'Something went wrong. Please try again.',
            onRetry: viewModel.refresh,
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({required this.state, required this.viewModel});

  final SettingsState state;
  final SettingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final settings = state.settings;
    final enabled = !state.isSaving;
    final pausedUntil = settings.isPausedAt(DateTime.now())
        ? settings.pausedUntil!.toLocal()
        : null;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (state.isSaving) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 16),
        ],
        if (state.error case final error?) ...[
          ErrorBanner(message: error.message),
          const SizedBox(height: 16),
        ],
        SettingsGroup(
          children: [
            SettingsRow(
              label: 'Active hours',
              value: '${settings.activeStart} to ${settings.activeEnd}',
              onTap: enabled ? () => _pickActiveHours(context) : null,
            ),
            SettingsRow(
              label: 'Remind me every',
              value: '${settings.reminderIntervalMin} min',
              onTap: enabled ? () => _pickInterval(context) : null,
            ),
            SettingsRow(
              label: 'Daily goal',
              value: '${settings.dailyGoal} breaks',
              onTap: enabled ? () => _pickGoal(context) : null,
            ),
            SettingsRow(
              label: 'Tone',
              value: SettingsOptions.toneShort(settings.tone),
              onTap: enabled ? () => _pickTone(context) : null,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsGroup(
          children: [
            SettingsRow(
              label: 'Quiet mode',
              subtitle: 'Reminders arrive silently, and still count.',
              trailing: Switch(
                value: settings.quietMode,
                onChanged: enabled ? viewModel.quietModeChanged : null,
              ),
              onTap: enabled
                  ? () => viewModel.quietModeChanged(!settings.quietMode)
                  : null,
            ),
            SettingsRow(
              label: 'Pause reminders',
              subtitle: pausedUntil != null
                  ? 'Paused until ${_formatDate(pausedUntil)}'
                  : 'Sick or on vacation? Take a break from reminders.',
              trailing: pausedUntil != null
                  ? TextButton(
                      onPressed: enabled ? viewModel.resume : null,
                      child: const Text('Resume'),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: enabled ? () => _pickPause(context) : null,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsGroup(
          children: [
            SettingsRow(
              label: 'Change password',
              trailing: const Icon(Icons.chevron_right),
              onTap: enabled
                  ? () => context.push(AppRoutes.changePassword)
                  : null,
            ),
            SettingsRow(
              label: 'Log out',
              labelColor: colors.secondary,
              onTap: enabled ? () => _logOut(context) : null,
            ),
          ],
        ),
        if (kDebugMode) ...[
          const SizedBox(height: 16),
          SettingsGroup(
            children: [
              SettingsRow(
                label: 'Fire test reminder (5 s)',
                subtitle: 'Debug only. Your schedule stays as it is.',
                trailing: const Icon(Icons.notifications_outlined),
                onTap: viewModel.fireTestReminder,
              ),
              SettingsRow(
                label: 'Reconcile now (debug)',
                subtitle:
                    'Debug only. Counts every pending reminder as expired.',
                trailing: const Icon(Icons.rule_outlined),
                onTap: () => _reconcileNowDebug(context),
              ),
              SettingsRow(
                label: 'Replay last op (debug)',
                subtitle: 'Debug only.',
                trailing: const Icon(Icons.replay_outlined),
                onTap: () => _replayLastOpDebug(context),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _logOut(BuildContext context) async {
    if (!await confirmLogOut(context) || !context.mounted) return;
    await viewModel.logOut();
    if (context.mounted) context.go(AppRoutes.logIn);
  }

  Future<void> _reconcileNowDebug(BuildContext context) =>
      _runDebug(context, viewModel.reconcileNowDebug);

  Future<void> _replayLastOpDebug(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await viewModel.replayLastOp();
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Replayed last op — watch the stats row')),
    );
  }

  Future<void> _runDebug(
    BuildContext context,
    Future<ReconcileOutcome> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final outcome = await action();
      final text = switch (outcome.status) {
        ReconcileStatus.counted =>
          'ignored ${outcome.ignored}, battery ${outcome.batteryPercent}%',
        ReconcileStatus.notCounted =>
          'Not counted: outside active hours or reminders paused',
        ReconcileStatus.nothingPending => 'Nothing to reconcile',
      };
      messenger.showSnackBar(SnackBar(content: Text(text)));
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _pickActiveHours(BuildContext context) async {
    final start = await pickTime(context, state.settings.activeStart);
    if (start == null || !context.mounted) return;
    final end = await pickTime(context, state.settings.activeEnd);
    if (end == null) return;
    await viewModel.activeHoursChanged(
      startHour: start.hour,
      startMinute: start.minute,
      endHour: end.hour,
      endMinute: end.minute,
    );
  }

  Future<void> _pickInterval(BuildContext context) async {
    final minutes = await showOptionSheet<int>(
      context,
      title: 'Remind me every',
      options: SettingsOptions.reminderIntervals,
      labelOf: (minutes) => '$minutes min',
      selected: state.settings.reminderIntervalMin,
    );
    if (minutes != null) await viewModel.reminderIntervalChanged(minutes);
  }

  Future<void> _pickGoal(BuildContext context) async {
    final goal = await showOptionSheet<int>(
      context,
      title: 'Daily goal',
      options: SettingsOptions.dailyGoals,
      labelOf: (goal) => goal == 1 ? '1 break' : '$goal breaks',
      selected: state.settings.dailyGoal,
    );
    if (goal != null) await viewModel.dailyGoalChanged(goal);
  }

  Future<void> _pickTone(BuildContext context) async {
    final tone = await showOptionSheet<String>(
      context,
      title: 'How should the app treat you?',
      options: SettingsOptions.tones,
      labelOf: (tone) => SettingsOptions.toneLabels[tone] ?? tone,
      selected: state.settings.tone,
    );
    if (tone != null) await viewModel.toneChanged(tone);
  }

  Future<void> _pickPause(BuildContext context) async {
    final option = await showOptionSheet<PauseOption>(
      context,
      title: 'Pause reminders for',
      options: PauseOption.values,
      labelOf: (option) => option.label,
    );
    if (option != null) await viewModel.pause(option);
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatDate(DateTime date) =>
      '${_months[date.month - 1]} ${date.day}, '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

class _SettingsError extends StatelessWidget {
  const _SettingsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ErrorBanner(message: message),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
