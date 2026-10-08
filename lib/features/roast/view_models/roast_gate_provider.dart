import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A projection of the current [UserStats] for the roast: whether it should
/// show (`roast_pending`) and the charge to paint (`roast_level`). Fed by
/// [HomeViewModel] whenever the stats change, so the router can redirect on
/// `pending` and the roast can paint the battery without re-fetching stats.
class RoastGateState {
  const RoastGateState({required this.pending, required this.roastLevel});

  final bool pending;
  final int roastLevel;
}

/// Always-alive and cheap, so the router reads it without touching the stats
/// provider.
class RoastGate extends Notifier<RoastGateState> {
  @override
  RoastGateState build() =>
      const RoastGateState(pending: false, roastLevel: 0);

  void update({required bool pending, required int roastLevel}) =>
      state = RoastGateState(pending: pending, roastLevel: roastLevel);
}

final roastGateProvider = NotifierProvider<RoastGate, RoastGateState>(
  RoastGate.new,
);
