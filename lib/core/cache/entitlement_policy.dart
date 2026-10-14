import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';

/// Reserved cache slot for the episode-6 entitlement payload (14-day Pro trial
/// and subscriptions). Defined now so a Pro user on a plane keeps Pro; no
/// purchase, paywall or entitlement logic exists yet, and nothing writes or
/// reads this slot today.
const entitlementSlot = 'entitlement';

/// Remote Config key for the offline grace window, in days.
const entitlementGraceConfigKey = 'entitlement_grace_days';

/// The grace window used when Remote Config has no usable value.
const defaultEntitlementGraceDays = 7;

/// How many days a last-known entitlement is honoured offline. Read from Remote
/// Config ([entitlementGraceConfigKey]); falls back to
/// [defaultEntitlementGraceDays] when absent or unusable. Reserved for episode
/// 6 — unused today.
Future<int> entitlementGraceDays({
  Future<String?> Function(String key)? readConfig,
}) async {
  final read = readConfig ?? AppAmbitSdk.getString;
  try {
    final parsed = int.tryParse((await read(entitlementGraceConfigKey))?.trim() ?? '');
    if (parsed != null && parsed > 0) return parsed;
  } catch (_) {
    // Remote Config unavailable: use the default.
  }
  return defaultEntitlementGraceDays;
}
