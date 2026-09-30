import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/models/auth_exception.dart';
import '../models/user_settings.dart';

/// Reads and edits the user's `user_settings` row and changes their password
/// through Cloud Code. The database is never touched directly from the app.
class SettingsRepository {
  const SettingsRepository();

  static const _timeout = Duration(seconds: 20);

  Future<UserSettings> fetch(String token) async =>
      UserSettings.fromJson(await _call('get_settings', {'token': token}));

  /// Sends only the changed fields; the server ignores anything it doesn't
  /// allow and returns the updated row.
  Future<UserSettings> update(
    String token,
    Map<String, Object?> settings,
  ) async => UserSettings.fromJson(
    await _call('update_settings', {'token': token, 'settings': settings}),
  );

  Future<void> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  }) => _call('auth_change_password', {
    'token': token,
    'old': oldPassword,
    'new': newPassword,
  });

  Future<Map<String, dynamic>> _call(
    String function,
    Map<String, Object?> body,
  ) async {
    try {
      final response = await CloudCode.call(
        function,
        body: body,
        timeout: _timeout,
      ).future;

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const AuthException(
          code: 'UNEXPECTED_RESPONSE',
          message: 'Unexpected response from the server.',
        );
      }

      final code = data['error'];
      if (code != null) {
        throw AuthException(
          code: code.toString(),
          message: (data['message'] ?? code).toString(),
        );
      }
      return data;
    } on CloudCodeError catch (e) {
      throw AuthException(
        code: e.code.name,
        message: e.code == CloudCodeErrorCode.http
            ? 'Something went wrong. Please try again.'
            : "Couldn't reach the server. Check your connection and try again.",
      );
    }
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => const SettingsRepository(),
);
