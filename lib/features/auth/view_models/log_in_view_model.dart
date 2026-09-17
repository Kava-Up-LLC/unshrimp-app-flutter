import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_exception.dart';
import '../models/log_in_state.dart';
import '../repositories/auth_repository.dart';
import '../repositories/token_storage.dart';

final logInViewModelProvider =
    NotifierProvider.autoDispose<LogInViewModel, LogInState>(
      LogInViewModel.new,
    );

class LogInViewModel extends Notifier<LogInState> {
  @override
  LogInState build() => const LogInState();

  void emailChanged(String value) =>
      state = state.copyWith(email: value, errorMessage: () => null);

  void passwordChanged(String value) =>
      state = state.copyWith(password: value, errorMessage: () => null);

  Future<void> submit() async {
    if (state.isLoading) return;
    if (state.email.trim().isEmpty || state.password.isEmpty) {
      state = state.copyWith(
        errorMessage: () => 'Enter your email and password.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      final token = await ref
          .read(authRepositoryProvider)
          .logIn(email: state.email.trim(), password: state.password);
      await ref.read(tokenStorageProvider).write(token);
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, isAuthenticated: true);
    } on AuthException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: () => e.message);
    }
  }
}
