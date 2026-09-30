import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local reminder data: the cached `sarcasm_pack` and whether the
/// notification permission screen was already shown.
class ReminderPreferences {
  const ReminderPreferences(this._prefs);

  static const _packKey = 'reminders.sarcasm_pack';
  static const _askedKey = 'reminders.permission_asked';

  final SharedPreferencesAsync _prefs;

  Future<String?> readSarcasmPack() => _prefs.getString(_packKey);

  Future<void> writeSarcasmPack(String raw) => _prefs.setString(_packKey, raw);

  Future<bool> wasPermissionAsked() async =>
      await _prefs.getBool(_askedKey) ?? false;

  Future<void> markPermissionAsked() => _prefs.setBool(_askedKey, true);
}

final reminderPreferencesProvider = Provider<ReminderPreferences>(
  (ref) => ReminderPreferences(SharedPreferencesAsync()),
);
