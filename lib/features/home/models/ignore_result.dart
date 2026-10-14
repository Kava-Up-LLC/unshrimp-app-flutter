import 'user_stats.dart';

/// The outcome of a `reconcile_ignored` call: [stats] is the (possibly
/// unchanged) row, and [ignored] is how many the server actually counted — 0
/// when the user is outside their active window or paused, otherwise the count.
class IgnoreResult {
  const IgnoreResult({required this.ignored, required this.stats});

  final int ignored;
  final UserStats stats;
}
