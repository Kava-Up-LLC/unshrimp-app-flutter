import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../subscriptions/widgets/pro_lock_tile.dart';
import '../models/weekly_report.dart';
import '../view_models/spine_report_share.dart';
import '../view_models/weekly_report_view_model.dart';

const _weekdayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Your spine this week": the last complete week's four numbers, the delta
/// against the week before, the spine's verdict, and a Share button that shares
/// the card as an image. For Free it is blurred behind a Pro lock.
class SpineWeekCard extends ConsumerStatefulWidget {
  const SpineWeekCard({super.key});

  @override
  ConsumerState<SpineWeekCard> createState() => _SpineWeekCardState();
}

class _SpineWeekCardState extends ConsumerState<SpineWeekCard> {
  // Stable across rebuilds so the RepaintBoundary can be captured to an image.
  final _boundaryKey = GlobalKey();

  Future<void> _share() async {
    final bytes = await ref.read(captureImageProvider)(_boundaryKey);
    if (bytes == null) return;
    await ref.read(shareImageProvider)(bytes, name: 'spine_report.png');
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(weeklyReportViewModelProvider);
    return switch (report) {
      AsyncData(:final value) when value.locked => const _LockedCard(),
      AsyncData(:final value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RepaintBoundary(
            key: _boundaryKey,
            child: _ReportCard(report: value),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _share,
            icon: const Icon(Icons.ios_share, size: 18),
            label: const Text('Share'),
          ),
        ],
      ),
      AsyncError() => const SizedBox.shrink(),
      _ => const _LoadingCard(),
    };
  }
}

/// The captured card: title, the four numbers, the delta line and the verdict.
class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final best = report.bestDay;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your spine this week',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    value: '${report.breaks}',
                    label: 'Breaks',
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Stat(
                    value: '${report.ignored}',
                    label: 'Ignored',
                    color: colors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    value: best == null ? '—' : _weekdayAbbr[best.weekday - 1],
                    label: 'Best day',
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Stat(
                    value: '${report.longestStreak}',
                    label: 'Longest streak',
                    color: colors.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DeltaLine(delta: report.breaksDelta),
            if (report.verdict != null) ...[
              const SizedBox(height: 12),
              Text(
                report.verdict!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// "▲ 6 more breaks than last week" / "▼ 3 fewer breaks than last week".
class _DeltaLine extends StatelessWidget {
  const _DeltaLine({required this.delta});

  final int delta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (text, color) = switch (delta) {
      > 0 => ('▲ $delta more ${_breaks(delta)} than last week', colors.primary),
      < 0 => (
        '▼ ${-delta} fewer ${_breaks(-delta)} than last week',
        colors.secondary,
      ),
      _ => ('Same as last week', colors.onSurfaceVariant),
    };
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static String _breaks(int n) => n == 1 ? 'break' : 'breaks';
}

/// The Free state: a blurred mock of the card behind an "Unlock your Spine
/// Report · Pro" lock that opens the Pro screen.
class _LockedCard extends StatelessWidget {
  const _LockedCard();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IgnorePointer(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
            child: _ReportCard(
              report: const WeeklyReport(
                locked: false,
                breaks: 24,
                ignored: 3,
                longestStreak: 4,
                breaksDelta: 6,
                verdict: 'Your spine is keeping score.',
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ProLockTile(
            label: 'Unlock your Spine Report',
            onTap: () => context.push(AppRoutes.pro),
          ),
        ),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
