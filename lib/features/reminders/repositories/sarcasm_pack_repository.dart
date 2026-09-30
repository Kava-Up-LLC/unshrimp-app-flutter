import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sarcasm_pack.dart';
import 'fallback_sarcasm_lines.dart';
import 'reminder_preferences.dart';

/// Loads the reminder one-liners. Order: Remote Config `sarcasm_pack` (cached
/// on success), the cached copy, the CMS `sarcasm_lines`, then
/// [fallbackSarcasmLines].
class SarcasmPackRepository {
  SarcasmPackRepository(
    this._prefs, {
    Future<String?> Function(String key)? readConfig,
    Future<List<String>> Function(String pack)? readCms,
  }) : _readConfig = readConfig ?? AppAmbitSdk.getString,
       _readCms = readCms ?? _cmsLines;

  static const configKey = 'sarcasm_pack';
  static const _cmsTimeout = Duration(seconds: 10);

  final ReminderPreferences _prefs;
  final Future<String?> Function(String key) _readConfig;
  final Future<List<String>> Function(String pack) _readCms;

  /// The pack in use and its lines. Text from the CMS or [fallbackSarcasmLines]
  /// counts as the default pack.
  Future<SarcasmPack> loadPack() async {
    try {
      final raw = await _readConfig(configKey);
      final remote = SarcasmPack.tryParse(raw);
      if (remote != null) {
        await _prefs.writeSarcasmPack(raw!);
        return remote;
      }
    } catch (_) {
      // Remote Config unavailable: use the cache.
    }

    try {
      final cached = SarcasmPack.tryParse(await _prefs.readSarcasmPack());
      if (cached != null) return cached;
    } catch (_) {
      // Unreadable cache: try the CMS.
    }

    try {
      final lines = await _readCms(SarcasmPack.defaultPack);
      if (lines.isNotEmpty) {
        return SarcasmPack(active: SarcasmPack.defaultPack, lines: lines);
      }
    } catch (_) {
      // Unreachable CMS: use the bundled lines.
    }
    return const SarcasmPack(
      active: SarcasmPack.defaultPack,
      lines: fallbackSarcasmLines,
    );
  }

  static Future<List<String>> _cmsLines(String pack) async {
    final lines = await AppAmbitCms.content(
      'sarcasm_lines',
      fromJson: (json) {
        final fields = json['data'] is Map ? json['data'] as Map : json;
        return fields['text']?.toString().trim() ?? '';
      },
    ).equals('pack', pack).getPerPage(50).getList().timeout(_cmsTimeout);
    return lines.where((line) => line.isNotEmpty).toList();
  }
}

final sarcasmPackRepositoryProvider = Provider<SarcasmPackRepository>(
  (ref) => SarcasmPackRepository(ref.read(reminderPreferencesProvider)),
);
