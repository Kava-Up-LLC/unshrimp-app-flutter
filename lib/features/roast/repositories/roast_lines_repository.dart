import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reminders/repositories/reminder_preferences.dart';
import '../models/roast_lines.dart';
import 'fallback_roast_lines.dart';

/// Loads the Posture Roast lines. Order: Remote Config `roast_lines` (cached on
/// success), the cached copy, then [fallbackRoastLines]. Always returns a
/// non-empty list, so a roast always has a line to show.
class RoastLinesRepository {
  RoastLinesRepository(
    this._prefs, {
    Future<String?> Function(String key)? readConfig,
  }) : _readConfig = readConfig ?? AppAmbitSdk.getString;

  static const configKey = 'roast_lines';

  final ReminderPreferences _prefs;
  final Future<String?> Function(String key) _readConfig;

  Future<List<String>> loadLines() async {
    try {
      final raw = await _readConfig(configKey);
      final remote = RoastLines.tryParse(raw);
      if (remote != null) {
        await _prefs.writeRoastLines(raw!);
        return remote;
      }
    } catch (_) {
      // Remote Config unavailable: fall back to the cache.
    }

    try {
      final cached = RoastLines.tryParse(await _prefs.readRoastLines());
      if (cached != null) return cached;
    } catch (_) {
      // Unreadable cache: fall back to the bundled lines.
    }

    return fallbackRoastLines;
  }
}

final roastLinesRepositoryProvider = Provider<RoastLinesRepository>(
  (ref) => RoastLinesRepository(ref.read(reminderPreferencesProvider)),
);
