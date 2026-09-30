import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/models/auth_exception.dart';
import '../models/seeded_settings.dart';

/// Sends the onboarding answers to the `save_onboarding` Cloud Code function,
/// which derives and seeds the user's settings on the server.
class OnboardingRepository {
  const OnboardingRepository();

  static const _timeout = Duration(seconds: 20);

  Future<SeededSettings> save({
    required String token,
    required Map<String, String> answers,
  }) async {
    try {
      final response = await CloudCode.call(
        'save_onboarding',
        body: {'token': token, 'answers': answers},
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

      return SeededSettings.fromJson(data);
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

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => const OnboardingRepository(),
);
