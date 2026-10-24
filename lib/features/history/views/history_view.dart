import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../auth/models/auth_exception.dart';
import '../../home/widgets/offline_indicator.dart';
import '../../subscriptions/widgets/pro_lock_tile.dart';
import '../models/stats_history.dart';
import '../view_models/history_view_model.dart';
import '../view_models/weekly_report_view_model.dart';
import '../widgets/history_summary.dart';
import '../widgets/history_today_card.dart';
import '../widgets/spine_week_card.dart';
import '../widgets/week_strip.dart';

/// History: today's card, a best-streak / goal-met summary, and one strip per
/// week. Reads `get_stats_history` through the cache, so it opens offline.
class HistoryView extends ConsumerStatefulWidget {
  const HistoryView({super.key});

  @override
  ConsumerState<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends ConsumerState<HistoryView> {
  // Scroll target for a push opened with `open=report`; scrolled to once.
  final _reportKey = GlobalKey();
  bool _scrolledToReport = false;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyViewModelProvider);
    final viewModel = ref.read(historyViewModelProvider.notifier);
    final focusReport =
        GoRouterState.of(context).uri.queryParameters['focus'] == 'report';

    // A rejected token ends the session, exactly as on Home.
    ref.listen(historyViewModelProvider, (_, next) {
      final error = next.error;
      if (error is AuthException && error.code == 'INVALID_TOKEN') {
        context.go(AppRoutes.logIn);
      }
    });

    if (focusReport && !_scrolledToReport) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _reportKey.currentContext;
        if (target != null) {
          _scrolledToReport = true;
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 300),
            alignment: 0.1,
          );
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: const [OfflineIndicator()],
      ),
      body: SafeArea(
        child: switch (history) {
          AsyncData(:final value) => RefreshIndicator(
            onRefresh: () => Future.wait([
              viewModel.reload(),
              ref.read(weeklyReportViewModelProvider.notifier).reload(),
            ]),
            child: _HistoryContent(history: value, reportKey: _reportKey),
          ),
          AsyncError(:final error) => _HistoryError(
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

class _HistoryContent extends StatelessWidget {
  const _HistoryContent({required this.history, required this.reportKey});

  final StatsHistory history;
  final GlobalKey reportKey;

  @override
  Widget build(BuildContext context) {
    final today = history.today;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        if (today != null) ...[
          HistoryTodayCard(today: today, dailyGoal: history.dailyGoal),
          const SizedBox(height: 16),
        ],
        // The weekly Spine Report, above the weeks. Free sees it blurred behind
        // its own Pro lock (its locked state follows the entitlement, not this
        // payload's is_pro).
        KeyedSubtree(key: reportKey, child: const SpineWeekCard()),
        const SizedBox(height: 24),
        // Free sees today's card, then the weeks blurred behind a Pro lock.
        if (!history.isPro)
          const _BlurredWeeks()
        else ...[
          HistorySummary(
            bestStreak: history.bestStreak,
            goalMetDays: history.goalMetDays,
          ),
          const SizedBox(height: 24),
          for (final week in history.activeWeeks) ...[
            WeekStrip(week: week, dailyGoal: history.dailyGoal),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

/// The locked history for Free: a blurred placeholder of week strips with a
/// "Unlock your history · Pro" lock over it. Tapping opens the Pro screen.
class _BlurredWeeks extends StatelessWidget {
  const _BlurredWeeks();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        IgnorePointer(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
            child: Column(
              children: [
                for (var w = 0; w < 3; w++) ...[
                  _FakeStrip(colors: colors),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ProLockTile(
            label: 'Unlock your history',
            onTap: () => context.push(AppRoutes.pro),
          ),
        ),
      ],
    );
  }
}

/// A decorative week-strip shape behind the blur — no real data.
class _FakeStrip extends StatelessWidget {
  const _FakeStrip({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var d = 0; d < 7; d++)
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: d.isEven ? colors.primary : colors.tertiary,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
