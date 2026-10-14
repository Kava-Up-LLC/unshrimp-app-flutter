import 'package:flutter_test/flutter_test.dart';
import 'package:move_well_app/core/cache/entitlement_policy.dart';

void main() {
  test('defaults to 7 days when Remote Config has no value', () async {
    expect(await entitlementGraceDays(readConfig: (_) async => null), 7);
  });

  test('uses the Remote Config value when present', () async {
    expect(await entitlementGraceDays(readConfig: (_) async => '14'), 14);
  });

  test('falls back to 7 on an unusable value, never throws', () async {
    expect(await entitlementGraceDays(readConfig: (_) async => 'nope'), 7);
    expect(await entitlementGraceDays(readConfig: (_) async => '0'), 7);
    expect(
      await entitlementGraceDays(readConfig: (_) async => throw Exception('down')),
      7,
    );
  });
}
