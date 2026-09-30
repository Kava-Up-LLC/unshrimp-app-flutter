import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/onboarding_question.dart';
import 'fallback_onboarding_questions.dart';

/// Reads the onboarding questions from the CMS content type
/// `onboarding_questions`, falling back to [fallbackOnboardingQuestions].
class OnboardingContentRepository {
  const OnboardingContentRepository();

  static const _timeout = Duration(seconds: 10);

  Future<List<OnboardingQuestion>> fetchQuestions() async {
    try {
      final questions = await AppAmbitCms.content(
        'onboarding_questions',
        fromJson: OnboardingQuestion.fromCms,
      ).getPerPage(50).getList().timeout(_timeout);

      // The SDK returns an empty list when the request fails.
      if (questions.isNotEmpty) {
        return questions..sort((a, b) => a.order.compareTo(b.order));
      }
    } catch (_) {
      // Unreachable CMS or malformed entry: use the local copy.
    }
    return fallbackOnboardingQuestions;
  }
}

final onboardingContentRepositoryProvider =
    Provider<OnboardingContentRepository>(
      (ref) => const OnboardingContentRepository(),
    );
