import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/models/auth_exception.dart';
import '../../auth/repositories/token_storage.dart';
import '../../reminders/services/reminder_scheduler.dart';
import '../models/onboarding_state.dart';
import '../models/question_type.dart';
import '../repositories/onboarding_content_repository.dart';
import '../repositories/onboarding_repository.dart';

final onboardingViewModelProvider =
    AsyncNotifierProvider.autoDispose<OnboardingViewModel, OnboardingState>(
      OnboardingViewModel.new,
    );

/// Walks the user through the questions, collects the raw answers and sends
/// them once to `save_onboarding`. Nothing is derived from them here.
class OnboardingViewModel extends AsyncNotifier<OnboardingState> {
  @override
  Future<OnboardingState> build() async {
    final questions = await ref
        .read(onboardingContentRepositoryProvider)
        .fetchQuestions();

    // Prefill the work-hours step with its defaults so it can be skipped as-is.
    final answers = <String, String>{
      for (final question in questions)
        if (question.type == QuestionType.timeRange) ...{
          OnboardingState.activeStartKey: ?question.defaultStart,
          OnboardingState.activeEndKey: ?question.defaultEnd,
        },
    };
    return OnboardingState(questions: questions, answers: answers);
  }

  void optionSelected(String value) =>
      _answer(state.requireValue.question.key, value);

  void startTimeChanged(int hour, int minute) =>
      _answer(OnboardingState.activeStartKey, _formatTime(hour, minute));

  void endTimeChanged(int hour, int minute) =>
      _answer(OnboardingState.activeEndKey, _formatTime(hour, minute));

  void back() {
    final current = state.requireValue;
    if (current.step == 0 || current.isSaving) return;
    state = AsyncData(
      current.copyWith(step: current.step - 1, error: () => null),
    );
  }

  /// Moves to the next step, or saves the answers on the last one.
  Future<void> next() async {
    final current = state.requireValue;
    if (!current.canContinue || current.isSaving) return;
    if (!current.isLastStep) {
      state = AsyncData(current.copyWith(step: current.step + 1));
      return;
    }

    state = AsyncData(current.copyWith(isSaving: true, error: () => null));
    try {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) {
        throw const AuthException(
          code: 'INVALID_TOKEN',
          message: 'Your session has expired. Please log in again.',
        );
      }
      await ref
          .read(onboardingRepositoryProvider)
          .save(token: token, answers: current.answers);
      // The settings now exist server-side: schedule from them.
      unawaited(ref.read(reminderSchedulerProvider).rescheduleFromServer());
      if (!ref.mounted) return;
      state = AsyncData(current.copyWith(isDone: true));
    } on AuthException catch (e) {
      if (!ref.mounted) return;
      state = AsyncData(current.copyWith(error: () => e));
    }
  }

  void _answer(String key, String value) {
    final current = state.requireValue;
    if (current.isSaving) return;
    state = AsyncData(
      current.copyWith(
        answers: {...current.answers, key: value},
        error: () => null,
      ),
    );
  }

  static String _formatTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
