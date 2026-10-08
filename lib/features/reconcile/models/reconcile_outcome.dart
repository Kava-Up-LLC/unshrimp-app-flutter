import 'reconcile_status.dart';

/// The result of a reconciliation (or the debug "register ignore"), shaped for
/// the debug SnackBars: how many the server counted and the resulting Spine
/// Battery charge.
class ReconcileOutcome {
  const ReconcileOutcome.nothingPending()
    : status = ReconcileStatus.nothingPending,
      ignored = 0,
      batteryPercent = 0;

  const ReconcileOutcome.notCounted()
    : status = ReconcileStatus.notCounted,
      ignored = 0,
      batteryPercent = 0;

  const ReconcileOutcome.counted({
    required this.ignored,
    required this.batteryPercent,
  }) : status = ReconcileStatus.counted;

  final ReconcileStatus status;
  final int ignored;
  final int batteryPercent;
}
