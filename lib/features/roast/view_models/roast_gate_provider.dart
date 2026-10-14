import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/outbox/outbox.dart';

/// A projection of the current [UserStats] for the roast: whether it should
/// show and the charge to paint (`roast_level`).
///
/// `pending` has two inputs, because the rule is *release what the user earned
/// by doing; hold back what the server computes*:
/// - [confirmedPending] — `roast_pending` from the real stats row (what the
///   server says), fed by [HomeViewModel].
/// - [released] — true while a COMPLETED break sits queued in the outbox but
///   unsynced. Holding a 60 s timer can't be faked, so a queued break lets the
///   user out of the roast at once, offline; `current_streak`/`roast_level`
///   still wait for the server's response.
///
/// Effective [pending] is `confirmedPending && !released`.
class RoastGateState {
  const RoastGateState({
    required this.confirmedPending,
    required this.released,
    required this.roastLevel,
  });

  final bool confirmedPending;
  final bool released;
  final int roastLevel;

  bool get pending => confirmedPending && !released;
}

/// Always-alive and cheap, so the router reads it without touching the stats
/// provider, and the roast can paint the battery without re-fetching stats.
class RoastGate extends Notifier<RoastGateState> {
  @override
  RoastGateState build() => const RoastGateState(
    confirmedPending: false,
    released: false,
    roastLevel: 0,
  );

  /// What the server's stats row says. Fed by [HomeViewModel] on every change.
  void setConfirmed({required bool pending, required int roastLevel}) =>
      state = RoastGateState(
        confirmedPending: pending,
        released: state.released,
        roastLevel: roastLevel,
      );

  /// Whether a queued completed break is holding the roast open locally. Fed by
  /// the outbox (see [roastReleaseFeederProvider]).
  void setReleased(bool released) => state = RoastGateState(
    confirmedPending: state.confirmedPending,
    released: released,
    roastLevel: state.roastLevel,
  );

  /// Clears both inputs, e.g. on log out.
  void reset() => state = const RoastGateState(
    confirmedPending: false,
    released: false,
    roastLevel: 0,
  );
}

final roastGateProvider = NotifierProvider<RoastGate, RoastGateState>(
  RoastGate.new,
);

/// Keeps the gate's local `released` flag in sync with the outbox: a queued
/// completed break releases the roast; draining the queue returns it to
/// whatever the confirmed stats say. Always alive (watched at the app root) so
/// it works even when Home is not mounted — e.g. while the roast screen itself
/// is up — and so the release is correct on a cold start, where the outbox
/// loads its persisted queue before Home builds.
final roastReleaseFeederProvider = Provider<void>((ref) {
  ref.listen(outboxProvider, (_, next) {
    final ops = next.value ?? const [];
    final released = ops.any((op) => op.function == 'register_break');
    // Deferred to a microtask so it never mutates a provider during a build
    // (fireImmediately's first call runs inside this provider's creation).
    Future.microtask(
      () => ref.read(roastGateProvider.notifier).setReleased(released),
    );
  }, fireImmediately: true);
});
