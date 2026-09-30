import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../shared/widgets/error_banner.dart';
import '../../shared/widgets/submit_button.dart';
import '../../shared/widgets/time_picker.dart';
import '../models/onboarding_state.dart';
import '../models/question_type.dart';
import '../view_models/onboarding_view_model.dart';
import '../widgets/choice_option_tile.dart';
import '../widgets/step_progress.dart';
import '../widgets/time_range_fields.dart';

/// The 4-step "Test of Shame": one question per screen, answers saved once
/// at the end.
class OnboardingView extends ConsumerWidget {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingViewModelProvider);
    final viewModel = ref.read(onboardingViewModelProvider.notifier);

    ref.listen(onboardingViewModelProvider, (_, next) {
      final value = next.value;
      if (value == null) return;
      if (value.isDone) context.go(AppRoutes.home);
      if (value.error?.code == 'INVALID_TOKEN') context.go(AppRoutes.logIn);
    });

    final step = onboarding.value?.step ?? 0;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: step > 0 ? BackButton(onPressed: viewModel.back) : null,
      ),
      body: SafeArea(
        child: switch (onboarding) {
          AsyncData(:final value) => _OnboardingStep(
            state: value,
            viewModel: viewModel,
          ),
          AsyncError() => const Padding(
            padding: EdgeInsets.all(24),
            child: ErrorBanner(
              message: 'Something went wrong. Please try again.',
            ),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({required this.state, required this.viewModel});

  final OnboardingState state;
  final OnboardingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final question = state.question;
    // Teal for the sitting and work-hours steps, coral for pain and tone.
    final accent = state.step < 2 ? colors.primary : colors.secondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StepProgress(step: state.step + 1, total: state.questions.length),
          const SizedBox(height: 20),
          Text(
            question.title,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            question.subtitle,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: switch (question.type) {
              QuestionType.singleChoice => ListView.separated(
                itemCount: question.options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final option = question.options[index];
                  return ChoiceOptionTile(
                    label: option.label,
                    description: option.description,
                    selected: state.answers[question.key] == option.value,
                    accent: accent,
                    onTap: () => viewModel.optionSelected(option.value),
                  );
                },
              ),
              QuestionType.timeRange => SingleChildScrollView(
                child: TimeRangeFields(
                  start: state.answers[OnboardingState.activeStartKey] ?? '',
                  end: state.answers[OnboardingState.activeEndKey] ?? '',
                  onStartTap: () => _pickTime(
                    context,
                    state.answers[OnboardingState.activeStartKey],
                    viewModel.startTimeChanged,
                  ),
                  onEndTap: () => _pickTime(
                    context,
                    state.answers[OnboardingState.activeEndKey],
                    viewModel.endTimeChanged,
                  ),
                ),
              ),
            },
          ),
          if (state.error case final error?) ...[
            ErrorBanner(message: error.message),
            const SizedBox(height: 16),
          ],
          SubmitButton(
            label: state.isLastStep ? 'Finish' : 'Continue',
            isLoading: state.isSaving,
            onPressed: state.canContinue ? viewModel.next : null,
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    String? current,
    void Function(int hour, int minute) onPicked,
  ) async {
    final picked = await pickTime(context, current);
    if (picked != null) onPicked(picked.hour, picked.minute);
  }
}
