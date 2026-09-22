import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_exception.dart';
import '../models/sign_up_state.dart';
import '../repositories/auth_repository.dart';
import '../repositories/token_storage.dart';

final signUpViewModelProvider =
    NotifierProvider.autoDispose<SignUpViewModel, SignUpState>(
      SignUpViewModel.new,
    );

class SignUpViewModel extends Notifier<SignUpState> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const _minPasswordLength = 8;

  @override
  SignUpState build() => const SignUpState();

  void nameChanged(String value) => state = state.copyWith(
    name: value,
    nameError: () => null,
    errorMessage: () => null,
  );

  void emailChanged(String value) => state = state.copyWith(
    email: value,
    emailError: () => null,
    errorMessage: () => null,
  );

  void passwordChanged(String value) => state = state.copyWith(
    password: value,
    passwordError: () => null,
    confirmPasswordError: () => null,
    errorMessage: () => null,
  );

  void confirmPasswordChanged(String value) => state = state.copyWith(
    confirmPassword: value,
    confirmPasswordError: () => null,
    errorMessage: () => null,
  );

  Future<void> submit() async {
    if (state.isLoading) return;

    // Format checks only; credentials are hashed and verified in AppAmbit.
    final name = state.name.trim();
    final email = state.email.trim();
    state = state.copyWith(
      nameError: () => name.isEmpty ? 'Enter your name.' : null,
      emailError: () =>
          _emailPattern.hasMatch(email) ? null : 'Enter a valid email.',
      passwordError: () => state.password.length < _minPasswordLength
          ? 'Use at least $_minPasswordLength characters.'
          : null,
      confirmPasswordError: () => state.confirmPassword != state.password
          ? 'Passwords do not match.'
          : null,
      errorMessage: () => null,
    );
    if (state.hasFieldErrors) return;

    state = state.copyWith(isLoading: true);
    try {
      final token = await ref
          .read(authRepositoryProvider)
          .register(name: name, email: email, password: state.password);
      await ref.read(tokenStorageProvider).write(token);
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, isAuthenticated: true);
    } on AuthException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: () => e.message);
    }
  }
}
