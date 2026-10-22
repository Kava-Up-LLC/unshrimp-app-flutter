/// What `get_entitlements` returns — the single source of truth for Pro. The
/// phone never decides this; it only reads what the cloud computed against its
/// own clock.
class Entitlement {
  const Entitlement({
    required this.isPro,
    required this.entitlement,
    this.trialEndsAt,
    this.proUntil,
  });

  /// Whether the user has Pro access right now, by trial or by payment.
  final bool isPro;

  /// The effective tier: `pro`, `pro_trial` or `free`.
  final String entitlement;

  /// When the free trial ends; null when there is (or was) no trial.
  final DateTime? trialEndsAt;

  /// When paid Pro ends; null when the user is not a paid subscriber.
  final DateTime? proUntil;

  bool get isTrial => entitlement == 'pro_trial';
  bool get isPaid => entitlement == 'pro';

  /// Whole days left in the trial from [now], rounded up so the last partial
  /// day still reads as "1". Zero when there is no trial or it has ended.
  int trialDaysLeft(DateTime now) {
    final ends = trialEndsAt;
    if (ends == null) return 0;
    final minutes = ends.difference(now).inMinutes;
    if (minutes <= 0) return 0;
    return (minutes / (60 * 24)).ceil();
  }

  /// The default for a user with no entitlement (and the offline-past-grace
  /// fallback): plain Free.
  static const free = Entitlement(isPro: false, entitlement: 'free');

  factory Entitlement.fromJson(Map<String, dynamic> json) => Entitlement(
    isPro: json['is_pro'] == true,
    entitlement: json['entitlement']?.toString() ?? 'free',
    trialEndsAt: DateTime.tryParse(json['trial_ends_at']?.toString() ?? ''),
    proUntil: DateTime.tryParse(json['pro_until']?.toString() ?? ''),
  );
}
