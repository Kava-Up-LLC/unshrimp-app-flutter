import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local reminder data: the cached `sarcasm_pack`, the cached
/// `roast_lines`, and whether the notification permission screen was shown.
class ReminderPreferences {
  const ReminderPreferences(this._prefs);

  static const _packKey = 'reminders.sarcasm_pack';
  static const _roastKey = 'reminders.roast_lines';
  static const _askedKey = 'reminders.permission_asked';

  final SharedPreferencesAsync _prefs;

  Future<String?> readSarcasmPack() => _prefs.getString(_packKey);

  Future<void> writeSarcasmPack(String raw) => _prefs.setString(_packKey, raw);

  Future<String?> readRoastLines() => _prefs.getString(_roastKey);

  Future<void> writeRoastLines(String raw) => _prefs.setString(_roastKey, raw);

  Future<bool> wasPermissionAsked() async =>
      await _prefs.getBool(_askedKey) ?? false;

  Future<void> markPermissionAsked() => _prefs.setBool(_askedKey, true);

  /// Removes every reminder preference. Used by log out and the no-session
  /// first run so the device keeps nothing from a previous install or user.
  Future<void> clear() async {
    await _prefs.remove(_packKey);
    await _prefs.remove(_roastKey);
    await _prefs.remove(_askedKey);
  }
}

final reminderPreferencesProvider = Provider<ReminderPreferences>(
  (ref) => ReminderPreferences(SharedPreferencesAsync()),
);
