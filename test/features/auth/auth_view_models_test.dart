import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_well_app/features/auth/models/auth_exception.dart';
import 'package:move_well_app/features/auth/models/session_status.dart';
import 'package:move_well_app/features/auth/repositories/auth_repository.dart';
import 'package:move_well_app/features/auth/repositories/token_storage.dart';
import 'package:move_well_app/features/auth/view_models/log_in_view_model.dart';
import 'package:move_well_app/features/auth/view_models/session_gate_view_model.dart';
import 'package:move_well_app/features/auth/view_models/sign_up_view_model.dart';

import 'fakes.dart';

ProviderContainer _container(FakeAuthRepository repo, FakeTokenStorage store) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      tokenStorageProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('SignUpViewModel', () {
    test('rejects bad format and mismatched passwords without calling '
        'the backend', () async {
      final repo = FakeAuthRepository();
      final container = _container(repo, FakeTokenStorage());
      container.listen(signUpViewModelProvider, (_, _) {});
      final vm = container.read(signUpViewModelProvider.notifier)
        ..nameChanged('Ada')
        ..emailChanged('not-an-email')
        ..passwordChanged('password1')
        ..confirmPasswordChanged('password2');

      await vm.submit();

      final state = container.read(signUpViewModelProvider);
      expect(state.emailError, isNotNull);
      expect(state.confirmPasswordError, isNotNull);
      expect(repo.calls, 0);
    });

    test('stores the token on success', () async {
      final store = FakeTokenStorage();
      final container = _container(FakeAuthRepository(), store);
      container.listen(signUpViewModelProvider, (_, _) {});
      final vm = container.read(signUpViewModelProvider.notifier)
        ..nameChanged('Ada')
        ..emailChanged('ada@example.com')
        ..passwordChanged('password1')
        ..confirmPasswordChanged('password1');

      await vm.submit();

      expect(container.read(signUpViewModelProvider).isAuthenticated, isTrue);
      expect(store.token, 'register-token');
    });
  });

  group('LogInViewModel', () {
    test('shows the backend INVALID_CREDENTIALS message', () async {
      final store = FakeTokenStorage();
      final repo = FakeAuthRepository(
        error: const AuthException(
          code: 'INVALID_CREDENTIALS',
          message: 'Invalid email or password.',
        ),
      );
      final container = _container(repo, store);
      container.listen(logInViewModelProvider, (_, _) {});
      final vm = container.read(logInViewModelProvider.notifier)
        ..emailChanged('ada@example.com')
        ..passwordChanged('wrong');

      await vm.submit();

      final state = container.read(logInViewModelProvider);
      expect(state.errorMessage, 'Invalid email or password.');
      expect(state.isLoading, isFalse);
      expect(store.token, isNull);
    });
  });

  group('SessionGateViewModel', () {
    test('no stored token -> unauthenticated', () async {
      final container = _container(FakeAuthRepository(), FakeTokenStorage());
      expect(
        await container.read(sessionGateViewModelProvider.future),
        SessionStatus.unauthenticated,
      );
    });

    test('valid token -> authenticated', () async {
      final container = _container(FakeAuthRepository(), FakeTokenStorage('t'));
      expect(
        await container.read(sessionGateViewModelProvider.future),
        SessionStatus.authenticated,
      );
    });

    test('invalid token -> unauthenticated and token cleared', () async {
      final store = FakeTokenStorage('t');
      final container = _container(FakeAuthRepository(valid: false), store);
      expect(
        await container.read(sessionGateViewModelProvider.future),
        SessionStatus.unauthenticated,
      );
      expect(store.token, isNull);
    });
  });
}
