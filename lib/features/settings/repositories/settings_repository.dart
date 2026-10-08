import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cloud/cloud_functions.dart';
import '../models/user_settings.dart';

/// Reads and edits the user's `user_settings` row and changes their password
/// through Cloud Code. The database is never touched directly from the app.
class SettingsRepository {
  const SettingsRepository([this._cloud = const CloudFunctions()]);

  final CloudFunctions _cloud;

  /// `get_settings`: the current settings row. Idempotent read → may retry once.
  Future<UserSettings> fetch(String token) async => UserSettings.fromJson(
    await _cloud.call('get_settings', {'token': token}, retry: true),
  );

  /// Sends only the changed fields; the server ignores anything it doesn't
  /// allow and returns the updated row.
  Future<UserSettings> update(
    String token,
    Map<String, Object?> settings,
  ) async => UserSettings.fromJson(
    await _cloud.call('update_settings', {'token': token, 'settings': settings}),
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
  (ref) => const SettingsRepository(),
);
