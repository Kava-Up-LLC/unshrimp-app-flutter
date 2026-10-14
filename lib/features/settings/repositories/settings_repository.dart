import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_store.dart';
import '../../../core/cache/cache_user_id.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/cloud/cloud_functions.dart';
import '../models/user_settings.dart';

/// Reads and edits the user's `user_settings` row and changes their password
/// through Cloud Code. The database is never touched directly from the app.
///
/// The read ([fetch]) goes through a per-user cache, so it returns the last
/// stored row offline instead of throwing; edits are never cached.
class SettingsRepository {
  const SettingsRepository({
    CloudFunctions cloud = const CloudFunctions(),
    required CacheStore cache,
  }) : _cloud = cloud,
       _cache = cache;

  final CloudFunctions _cloud;
  final CacheStore _cache;

  /// `get_settings`: the current settings row, cached per user. Idempotent read
  /// → may retry once. On a transport failure the stored row is returned with
  /// [CacheResult.offline] set; a function-level error (NO_SETTINGS, …) still
  /// throws.
  Future<CacheResult<UserSettings>> fetch(String token) =>
      CachedRead<UserSettings>(
        store: _cache,
        decode: UserSettings.fromJson,
      ).read(
        userId: cacheUserIdFromToken(token),
        slot: 'settings',
        fetch: () => _cloud.call('get_settings', {'token': token}, retry: true),
      );

  /// Sends only the changed fields; the server ignores anything it doesn't
  /// allow and returns the updated row.
  Future<UserSettings> update(
    String token,
    Map<String, Object?> settings,
  ) async => UserSettings.fromJson(
    await _cloud.call('update_settings', {
      'token': token,
      'settings': settings,
    }),
  );

  Future<void> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  }) => _cloud.call('auth_change_password', {
    'token': token,
    'old': oldPassword,
    'new': newPassword,
  });
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(cache: ref.read(cacheStoreProvider)),
);
