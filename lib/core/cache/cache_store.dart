import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One cached Cloud Code payload and when it was stored.
class CacheEntry {
  const CacheEntry({required this.payload, required this.asOf});

  /// The raw reply body, exactly as Cloud Code returned it.
  final Map<String, dynamic> payload;

  /// When this payload was written.
  final DateTime asOf;

  /// Whether a payload stored [asOf] is still inside an [days]-day grace window
  /// from [now]. Reserved for the episode-6 entitlement slot, which is honoured
  /// offline for a grace period; unused by every other slot.
  bool isWithinGrace(int days, {DateTime? now}) =>
      (now ?? DateTime.now()).difference(asOf) <= Duration(days: days);
}

/// Device-local read cache for Cloud Code payloads, on `shared_preferences`.
///
/// Every entry is keyed by `cache.<schemaVersion>.<userId>.<slot>`, so a second
/// account on the same device never reads the first one's data, and a schema
/// change (bumping [schemaVersion]) orphans every old key instead of decoding a
/// stale shape. A value that does not match the current envelope is discarded,
/// never thrown, so an upgrade can never crash on an old payload.
class CacheStore {
  const CacheStore(this._prefs);

  /// Bump this when the stored envelope or any payload shape changes. Old keys
  /// are then never read again.
  static const schemaVersion = 'v1';

  static const _prefix = 'cache.';

  final SharedPreferencesAsync _prefs;

  static String _key(String userId, String slot) =>
      '$_prefix$schemaVersion.$userId.$slot';

  /// The stored entry for [userId]/[slot], or null when absent or unreadable.
  Future<CacheEntry?> read(String userId, String slot) async {
    try {
      final raw = await _prefs.getString(_key(userId, slot));
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final at = DateTime.tryParse(decoded['at']?.toString() ?? '');
      final payload = decoded['payload'];
      if (at == null || payload is! Map) return null;
      return CacheEntry(payload: Map<String, dynamic>.from(payload), asOf: at);
    } catch (_) {
      // Malformed or old-shape value: treat as a miss, never crash.
      return null;
    }
  }

  Future<void> write(
    String userId,
    String slot,
    Map<String, dynamic> payload,
  ) => _prefs.setString(
    _key(userId, slot),
    jsonEncode({'at': DateTime.now().toIso8601String(), 'payload': payload}),
  );

  /// Removes every entry for [userId]. Used on log out so the next account on
  /// the device starts from nothing.
  Future<void> clearUser(String userId) =>
      _removeMatching('$_prefix$schemaVersion.$userId.');

  /// Removes every cached entry, for every user and schema version. Used on a
  /// no-session launch, where the owning user id is unknown.
  Future<void> clearAll() => _removeMatching(_prefix);

  Future<void> _removeMatching(String prefix) async {
    final keys = await _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(prefix)) await _prefs.remove(key);
    }
  }
}

final cacheStoreProvider = Provider<CacheStore>(
  (ref) => CacheStore(SharedPreferencesAsync()),
);
