import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/auth/models/auth_exception.dart';
import 'package:unshrimp_app/features/auth/repositories/token_storage.dart';
import 'package:unshrimp_app/features/onboarding/models/onboarding_state.dart';
import 'package:unshrimp_app/features/onboarding/repositories/onboarding_content_repository.dart';
import 'package:unshrimp_app/features/onboarding/repositories/onboarding_repository.dart';
import 'package:unshrimp_app/features/onboarding/view_models/onboarding_view_model.dart';
import 'package:unshrimp_app/features/reminders/services/reminder_scheduler.dart';

import '../auth/fakes.dart';
import '../reminders/fakes.dart';
import 'fakes.dart';

Future<ProviderContainer> _container(
  FakeOnboardingRepository repo, [
  FakeTokenStorage? store,
  FakeReminderScheduler? scheduler,
]) async {
  final container = ProviderContainer(
    overrides: [
      onboardingContentRepositoryProvider.overrideWithValue(
        FakeOnboardingContentRepository(),
      ),
      onboardingRepositoryProvider.overrideWithValue(repo),
      tokenStorageProvider.overrideWithValue(store ?? FakeTokenStorage('t')),
      reminderSchedulerProvider.overrideWithValue(
        scheduler ?? FakeReminderScheduler(),
      ),
    ],
  );
  addTearDown(container.dispose);
  // Keeps the autoDispose provider alive while the test drives it.
  container.listen(onboardingViewModelProvider, (_, _) {});
  await container.read(onboardingViewModelProvider.future);
  return container;
}

OnboardingState _state(ProviderContainer c) =>
    c.read(onboardingViewModelProvider).requireValue;

OnboardingViewModel _vm(ProviderContainer c) =>
    c.read(onboardingViewModelProvider.notifier);

/// Answers the four steps, finishing on the last one.
Future<void> _completeFlow(ProviderContainer c) async {
  final vm = _vm(c);
  vm.optionSelected('4-8');
  await vm.next();
  vm.startTimeChanged(8, 30);
  vm.endTimeChanged(17, 5);
  await vm.next();
  vm.optionSelected('shoulders');
  await vm.next();
  vm.optionSelected('direct');
  await vm.next();
}

void main() {
  test('starts on step 1 with the work-hours defaults prefilled', () async {
    final c = await _container(FakeOnboardingRepository());

    final state = _state(c);
    expect(state.step, 0);
    expect(state.question.key, 'sitting_hours');
    expect(state.answers, {'active_start': '09:00', 'active_end': '18:00'});
  });

  test('a single-choice step needs a pick before Continue', () async {
    final c = await _container(FakeOnboardingRepository());

    await _vm(c).next();
    expect(_state(c).step, 0);

    _vm(c).optionSelected('8-12');
    await _vm(c).next();
    expect(_state(c).step, 1);
  });

  test('back returns to the previous step keeping the answer', () async {
    final c = await _container(FakeOnboardingRepository());

    _vm(c).optionSelected('0-4');
    await _vm(c).next();
    _vm(c).back();

    expect(_state(c).step, 0);
    expect(_state(c).answers['sitting_hours'], '0-4');
  });

  test('Finish sends the raw answers once and marks it done', () async {
    final repo = FakeOnboardingRepository();
    final scheduler = FakeReminderScheduler();
    final c = await _container(repo, null, scheduler);

    await _completeFlow(c);

    expect(repo.calls, hasLength(1));
    expect(repo.calls.single.token, 't');
    expect(repo.calls.single.answers, {
      'sitting_hours': '4-8',
      'active_start': '08:30',
      'active_end': '17:05',
      'pain_zone': 'shoulders',
      'tone': 'direct',
    });
    expect(_state(c).isDone, isTrue);
    expect(scheduler.fromServerCalls, 1);
  });

  test('a backend error stays on the last step with its message', () async {
    final repo = FakeOnboardingRepository(
      error: const AuthException(
        code: 'INVALID_ANSWERS',
        message: 'Your work hours must end after they start.',
      ),
    );
    final c = await _container(repo);

    await _completeFlow(c);

    final state = _state(c);
    expect(state.isDone, isFalse);
    expect(state.isSaving, isFalse);
    expect(state.step, 3);
    expect(state.error?.message, 'Your work hours must end after they start.');
  });

  test(
    'a missing token fails with INVALID_TOKEN without calling the server',
    () async {
      final repo = FakeOnboardingRepository();
      final c = await _container(repo, FakeTokenStorage());

      await _completeFlow(c);

      expect(repo.calls, isEmpty);
      expect(_state(c).error?.code, 'INVALID_TOKEN');
    },
  );
}
