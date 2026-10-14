import 'user_stats.dart';

/// What Home paints: the confirmed [stats] with any queued-but-unsynced work
/// laid on top, and whether a "waiting to sync" marker is due.
class HomeDisplay {
  const HomeDisplay({required this.stats, required this.waitingToSync});

  final UserStats stats;
  final bool waitingToSync;
}
