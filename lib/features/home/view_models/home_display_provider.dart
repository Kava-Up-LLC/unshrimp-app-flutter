import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/outbox/outbox.dart';
import '../models/home_display.dart';
import 'home_view_model.dart';

/// Home's displayed stats: the confirmed row from [HomeViewModel] with the
/// outbox's queued-but-unsynced breaks laid on top.
///
/// `breaks_today` is shown optimistically (confirmed + queued) with a "waiting
/// to sync" marker, and `roast_pending` is released while a break is queued —
/// the UI must not lie by hiding a break the user did. But `current_streak` and
/// `roast_level` are NEVER touched locally: the cloud computes them, so they
/// move only on a real response. When the flush lands, the queue empties and
/// the display falls back to the confirmed row.
final homeDisplayProvider = Provider.autoDispose<AsyncValue<HomeDisplay>>((
  ref,
) {
  final statsAsync = ref.watch(homeViewModelProvider);
  final ops = ref.watch(outboxProvider).value ?? const [];
  final queuedBreaks = ops
      .where((op) => op.function == 'register_break')
      .length;

  return statsAsync.whenData((stats) {
    if (queuedBreaks == 0) {
      return HomeDisplay(stats: stats, waitingToSync: false);
    }
    return HomeDisplay(
      stats: stats.copyWith(
        breaksToday: stats.breaksToday + queuedBreaks,
        roastPending: false, // a queued completed break releases the roast
      ),
      waitingToSync: true,
    );
  });
});
