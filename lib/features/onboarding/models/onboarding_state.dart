import '../../auth/models/auth_exception.dart';
import 'onboarding_question.dart';
import 'question_type.dart';

/// State of the onboarding flow: the questions, the current step and the raw
/// answers. Answers are sent as-is to `save_onboarding`, which derives the
/// user's settings on the server.
class OnboardingState {
  const OnboardingState({
    required this.questions,
    this.step = 0,
    this.answers = const {},
    this.isSaving = false,
    this.error,
    this.isDone = false,
  });

  /// Answer keys of the work-hours question, as `save_onboarding` expects them.
  static const activeStartKey = 'active_start';
  static const activeEndKey = 'active_end';

  final List<OnboardingQuestion> questions;
  final int step;

  /// Raw answers keyed by `save_onboarding`'s answer keys.
  final Map<String, String> answers;
  final bool isSaving;
  final AuthException? error;
  final bool isDone;

  OnboardingQuestion get question => questions[step];
  bool get isLastStep => step == questions.length - 1;

  /// Single-choice steps need a pick; the work-hours step starts prefilled.
  bool get canContinue =>
      question.type == QuestionType.timeRange ||
      answers.containsKey(question.key);

  OnboardingState copyWith({
    int? step,
    Map<String, String>? answers,
    bool? isSaving,
    AuthException? Function()? error,
    bool? isDone,
  }) {
    return OnboardingState(
      questions: questions,
      step: step ?? this.step,
      answers: answers ?? this.answers,
      isSaving: isSaving ?? this.isSaving,
      error: error != null ? error() : this.error,
      isDone: isDone ?? this.isDone,
    );
  }
}
