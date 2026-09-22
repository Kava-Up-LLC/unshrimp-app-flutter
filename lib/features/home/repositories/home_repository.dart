import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/models/auth_exception.dart';
import '../models/user_stats.dart';

/// Reads the logged-in user's stats through the `get_user_stats` Cloud Code
/// function. The database is never touched directly from the app.
class HomeRepository {
  const HomeRepository();

  static const _timeout = Duration(seconds: 20);

  Future<UserStats> fetchStats(String token) async {
    try {
      final response = await CloudCode.call(
        'get_user_stats',
        body: {'token': token},
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

      return UserStats.fromJson(data);
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

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => const HomeRepository(),
);
