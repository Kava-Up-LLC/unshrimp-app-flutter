import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_session.dart';

/// Persists the session token and its expiry in the platform's secure storage.
class TokenStorage {
  const TokenStorage(this._storage);

  static const _tokenKey = 'auth_token';
  static const _expiresAtKey = 'auth_expires_at';

  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _tokenKey);

  /// The stored expiry, or null for a legacy token saved before expiries were
  /// stored (or when none is present).
  Future<DateTime?> readExpiresAt() async {
    final raw = await _storage.read(key: _expiresAtKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Writes the token and its expiry together. The expiry is written first and
  /// the token last, so a token is never left pointing at a stale expiry; on a
  /// refresh the caller only calls this once the new pair is in hand, so a
  /// failed refresh leaves the old pair untouched.
  Future<void> writeSession(AuthSession session) async {
    final expiresAt = session.expiresAt;
    if (expiresAt != null) {
      await _storage.write(
        key: _expiresAtKey,
        value: expiresAt.toIso8601String(),
      );
    } else {
      await _storage.delete(key: _expiresAtKey);
    }
    await _storage.write(key: _tokenKey, value: session.token);
  }

  Future<void> delete() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _expiresAtKey);
  }
}

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => const TokenStorage(FlutterSecureStorage()),
);
