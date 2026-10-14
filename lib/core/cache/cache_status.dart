import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cached_read.dart';

/// Whether the app is currently serving cached data because the network is
/// unreachable, and — when it is — when that data was stored.
class CacheStatus {
  const CacheStatus({this.offline = false, this.asOf});

  final bool offline;
  final DateTime? asOf;
}

/// The app-wide offline flag, inferred from the outcome of the last cached
/// read: a transport failure flips it on with the cached data's age, a
/// successful call flips it off. No connectivity plugin is involved.
class CacheStatusNotifier extends Notifier<CacheStatus> {
  @override
  CacheStatus build() => const CacheStatus();

  /// Records the outcome of a cached read.
  void apply<T>(CacheResult<T> result) {
    // Every successful (online) read bumps the tick the outbox flushes on.
    if (!result.offline) ref.read(readSuccessTickProvider.notifier).bump();
    state = result.offline
        ? CacheStatus(offline: true, asOf: result.asOf)
        : const CacheStatus();
  }
}

final cacheStatusProvider = NotifierProvider<CacheStatusNotifier, CacheStatus>(
  CacheStatusNotifier.new,
);

/// A counter bumped on every successful (online) read.
///
/// The write outbox listens to this to flush after ANY successful call while
/// its queue is non-empty — not only on an offline→online edge. A mutation can
/// queue after a transport timeout or 5xx while the app was online (the
/// documented cold-start >10 s timeout), in which case [CacheStatus] never
/// flips to offline and there is no edge to react to; this tick still fires.
class ReadSuccessTick extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final readSuccessTickProvider = NotifierProvider<ReadSuccessTick, int>(
  ReadSuccessTick.new,
);
