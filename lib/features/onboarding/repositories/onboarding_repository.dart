import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cloud/cloud_functions.dart';
import '../models/seeded_settings.dart';

/// Sends the onboarding answers to the `save_onboarding` Cloud Code function,
/// which derives and seeds the user's settings on the server.
class OnboardingRepository {
  const OnboardingRepository([this._cloud = const CloudFunctions()]);

  final CloudFunctions _cloud;

  Future<SeededSettings> save({
    required String token,
    required Map<String, String> answers,
  }) async => SeededSettings.fromJson(
    await _cloud.call('save_onboarding', {'token': token, 'answers': answers}),
  );
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => const OnboardingRepository(),
);
