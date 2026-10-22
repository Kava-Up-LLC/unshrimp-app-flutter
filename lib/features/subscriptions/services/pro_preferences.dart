import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local one-time flags for the Pro flow: whether the "Your 14-day Pro
/// trial has started" screen and the "Your Pro trial ended" sheet have already
/// been shown. Cleared on log out so the next account on the device starts
/// fresh (same pattern as [ReminderPreferences]).
class ProPreferences {
  const ProPreferences(this._prefs);

  static const _startedKey = 'pro.trial_started_shown';
  static const _endedKey = 'pro.trial_ended_shown';

  final SharedPreferencesAsync _prefs;

  Future<bool> wasTrialStartedShown() async =>
      await _prefs.getBool(_startedKey) ?? false;

  Future<void> markTrialStartedShown() => _prefs.setBool(_startedKey, true);

  Future<bool> wasTrialEndedShown() async =>
      await _prefs.getBool(_endedKey) ?? false;

  Future<void> markTrialEndedShown() => _prefs.setBool(_endedKey, true);

  Future<void> clear() async {
    await _prefs.remove(_startedKey);
    await _prefs.remove(_endedKey);
  }
}

final proPreferencesProvider = Provider<ProPreferences>(
  (ref) => ProPreferences(SharedPreferencesAsync()),
);
