import 'package:move_well_app/features/auth/models/auth_exception.dart';
import 'package:move_well_app/features/onboarding/models/onboarding_question.dart';
import 'package:move_well_app/features/onboarding/models/seeded_settings.dart';
import 'package:move_well_app/features/onboarding/repositories/fallback_onboarding_questions.dart';
import 'package:move_well_app/features/onboarding/repositories/onboarding_content_repository.dart';
import 'package:move_well_app/features/onboarding/repositories/onboarding_repository.dart';

class FakeOnboardingContentRepository implements OnboardingContentRepository {
  @override
  Future<List<OnboardingQuestion>> fetchQuestions() async =>
      fallbackOnboardingQuestions;
}

const testSeeded = SeededSettings(
  userId: 3,
  activeStart: '09:00',
  activeEnd: '18:00',
  reminderIntervalMin: 60,
  graceWindowMin: 60,
  dailyGoal: 5,
  roastThreshold: 3,
  painZone: 'shoulders',
  quietMode: false,
  pausedUntil: null,
  archetype: 'Office Shrimp',
);

class FakeOnboardingRepository implements OnboardingRepository {
  FakeOnboardingRepository({this.error});

  final AuthException? error;
  final calls = <({String token, Map<String, String> answers})>[];

  @override
  Future<SeededSettings> save({
    required String token,
    required Map<String, String> answers,
  }) async {
    calls.add((token: token, answers: answers));
    if (error != null) throw error!;
    return testSeeded;
  }
}
