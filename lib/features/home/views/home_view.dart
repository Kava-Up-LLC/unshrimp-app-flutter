import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../auth/models/auth_exception.dart';
import '../../break/models/break_args.dart';
import '../../break/models/break_source.dart';
import '../../notifications/view_models/has_unread_notifications_view_model.dart';
import '../../shared/widgets/log_out_dialog.dart';
import '../models/user_stats.dart';
import '../view_models/home_view_model.dart';
import '../widgets/breaks_today_card.dart';
import '../widgets/notifications_bell.dart';
import '../widgets/spine_battery_card.dart';
import '../widgets/spine_streak_card.dart';

/// Home: the logged-in user's streak, Spine Battery and today's breaks.
class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(homeViewModelProvider);
    final viewModel = ref.read(homeViewModelProvider.notifier);
    final hasUnread = ref.watch(hasUnreadNotificationsProvider).value ?? false;

    // A rejected token means the session is over, wherever it was rejected.
    ref.listen(homeViewModelProvider, (_, next) {
      final error = next.error;
      if (error is AuthException && error.code == 'INVALID_TOKEN') {
        context.go(AppRoutes.logIn);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unshrimp'),
        actions: [
          NotificationsBell(
            hasUnread: hasUnread,
            onPressed: () => context.push(AppRoutes.notifications),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              if (!await confirmLogOut(context) || !context.mounted) return;
              await viewModel.logOut();
              if (context.mounted) context.go(AppRoutes.logIn);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: switch (stats) {
          AsyncData(:final value) => _HomeContent(stats: value),
          AsyncError(:final error) => _HomeError(
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

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.stats});

  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Hi ${stats.name}',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        SpineStreakCard(currentStreak: stats.currentStreak),
        const SizedBox(height: 16),
        SpineBatteryCard(roastLevel: stats.roastLevel),
        const SizedBox(height: 16),
        BreaksTodayCard(breaksToday: stats.breaksToday),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: () =>
              context.push(const BreakArgs(source: BreakSource.home).location),
          icon: const Icon(Icons.accessibility_new),
          label: const Text('Take a break now'),
        ),
      ],
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: colors.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
