import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'queued_op.dart';

/// Device-local persistence for the write outbox, on `shared_preferences`.
///
/// Keyed by `outbox.<schemaVersion>.<userId>.<slot>`, mirroring [CacheStore]:
/// a second account on the same device never sees the first one's queue, and a
/// schema bump orphans old keys instead of decoding a stale shape. Two slots:
/// `queue` (the FIFO list of pending ops) and `lastApplied` (the most recent op
/// that actually applied, for the debug replay). A value that doesn't match the
/// current shape is discarded, never thrown.
class OutboxStore {
  const OutboxStore(this._prefs);

  static const schemaVersion = 'v1';
  static const _prefix = 'outbox.';

  final SharedPreferencesAsync _prefs;

  String _queueKey(String userId) => '$_prefix$schemaVersion.$userId.queue';
  String _lastAppliedKey(String userId) =>
      '$_prefix$schemaVersion.$userId.lastApplied';

  /// The persisted FIFO queue for [userId], oldest first. Empty on a miss or an
  /// unreadable value.
  Future<List<QueuedOp>> loadQueue(String userId) async {
    try {
      final raw = await _prefs.getString(_queueKey(userId));
      if (raw == null) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.map(QueuedOp.fromJson).whereType<QueuedOp>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveQueue(String userId, List<QueuedOp> ops) => _prefs.setString(
    _queueKey(userId),
    jsonEncode(ops.map((op) => op.toJson()).toList()),
  );

  /// The last op that actually applied for [userId], or null. Used by the debug
  /// "Replay last op" row to re-queue it under its original id.
  Future<QueuedOp?> loadLastApplied(String userId) async {
    try {
      final raw = await _prefs.getString(_lastAppliedKey(userId));
      if (raw == null) return null;
      return QueuedOp.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLastApplied(String userId, QueuedOp op) =>
      _prefs.setString(_lastAppliedKey(userId), jsonEncode(op.toJson()));

  /// Removes both slots for [userId]. Used on log out so the next account on the
  /// device starts from nothing.
  Future<void> clearUser(String userId) async {
    await _prefs.remove(_queueKey(userId));
    await _prefs.remove(_lastAppliedKey(userId));
  }

  /// Removes every outbox entry, for every user and schema version. Used on a
  /// no-session launch, where the owning user id is unknown, so a fresh install
  /// never replays a prior install's queue.
  Future<void> clearAll() async {
    final keys = await _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_prefix)) await _prefs.remove(key);
    }
  }
}

final outboxStoreProvider = Provider<OutboxStore>(
  (ref) => OutboxStore(SharedPreferencesAsync()),
);
