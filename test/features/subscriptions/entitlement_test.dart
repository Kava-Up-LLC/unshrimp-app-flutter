import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/subscriptions/models/entitlement.dart';

void main() {
  final now = DateTime(2026, 10, 20, 12);

  test('fromJson reads the cloud shape', () {
    final ent = Entitlement.fromJson({
      'is_pro': true,
      'entitlement': 'pro_trial',
      'trial_ends_at': '2026-11-03T12:00:00.000Z',
      'pro_until': null,
    });
    expect(ent.isPro, isTrue);
    expect(ent.isTrial, isTrue);
    expect(ent.isPaid, isFalse);
    expect(ent.trialEndsAt, DateTime.utc(2026, 11, 3, 12));
    expect(ent.proUntil, isNull);
  });

  test('trialDaysLeft counts whole days, rounding the last partial day up', () {
    Entitlement trial(Duration left) => Entitlement(
      isPro: true,
      entitlement: 'pro_trial',
      trialEndsAt: now.add(left),
    );
    expect(trial(const Duration(days: 14)).trialDaysLeft(now), 14);
    expect(trial(const Duration(hours: 36)).trialDaysLeft(now), 2); // 1.5 days -> 2
    expect(trial(const Duration(hours: 1)).trialDaysLeft(now), 1);
    expect(trial(const Duration(hours: -1)).trialDaysLeft(now), 0); // ended
  });

  test('a free entitlement has no trial days', () {
    expect(Entitlement.free.trialDaysLeft(now), 0);
    expect(Entitlement.free.isPro, isFalse);
  });
}
