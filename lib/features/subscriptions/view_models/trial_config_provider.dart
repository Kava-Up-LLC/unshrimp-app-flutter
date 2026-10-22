import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Remote Config key for how many days before the trial ends to warn.
const trialWarningDaysConfigKey = 'trial_warning_days';
const defaultTrialWarningDays = 2;

/// Remote Config key for the trial-warning notification body.
const trialWarningTextConfigKey = 'trial_warning_text';
const defaultTrialWarningText =
    'Your trial ends soon. Your spine does not care.';

/// How many days before `trial_ends_at` the amber pill and the warning
/// notification kick in, from Remote Config (default [defaultTrialWarningDays]).
Future<int> trialWarningDays({
  Future<String?> Function(String key)? readConfig,
}) async {
  final read = readConfig ?? AppAmbitSdk.getString;
  try {
    final n = int.tryParse((await read(trialWarningDaysConfigKey))?.trim() ?? '');
    if (n != null && n > 0) return n;
  } catch (_) {
    // Remote Config unavailable: use the default.
  }
  return defaultTrialWarningDays;
}

/// The trial-warning notification body, from Remote Config (default
/// [defaultTrialWarningText]).
Future<String> trialWarningText({
  Future<String?> Function(String key)? readConfig,
}) async {
  final read = readConfig ?? AppAmbitSdk.getString;
  try {
    final text = (await read(trialWarningTextConfigKey))?.trim();
    if (text != null && text.isNotEmpty) return text;
  } catch (_) {
    // Remote Config unavailable: use the default.
  }
  return defaultTrialWarningText;
}

final trialWarningDaysProvider = FutureProvider<int>(
  (ref) => trialWarningDays(),
);
