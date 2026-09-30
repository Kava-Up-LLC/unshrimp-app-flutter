import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/models/auth_exception.dart';
import '../../auth/repositories/token_storage.dart';
import '../models/change_password_state.dart';
import '../repositories/settings_repository.dart';

final changePasswordViewModelProvider =
    NotifierProvider.autoDispose<ChangePasswordViewModel, ChangePasswordState>(
      ChangePasswordViewModel.new,
    );

class ChangePasswordViewModel extends Notifier<ChangePasswordState> {
  static const _minPasswordLength = 8;

  @override
  ChangePasswordState build() => const ChangePasswordState();

  void oldPasswordChanged(String value) => state = state.copyWith(
    oldPassword: value,
    oldPasswordError: () => null,
    errorCode: () => null,
    errorMessage: () => null,
  );

  void newPasswordChanged(String value) => state = state.copyWith(
    newPassword: value,
    newPasswordError: () => null,
    confirmPasswordError: () => null,
    errorCode: () => null,
    errorMessage: () => null,
  );

  void confirmPasswordChanged(String value) => state = state.copyWith(
    confirmPassword: value,
    confirmPasswordError: () => null,
    errorCode: () => null,
    errorMessage: () => null,
  );

  Future<void> submit() async {
    if (state.isLoading) return;

    // Format checks only; the old password is verified in AppAmbit.
    state = state.copyWith(
      oldPasswordError: () =>
          state.oldPassword.isEmpty ? 'Enter your current password.' : null,
      newPasswordError: () => state.newPassword.length < _minPasswordLength
          ? 'Use at least $_minPasswordLength characters.'
          : null,
      confirmPasswordError: () => state.confirmPassword != state.newPassword
          ? 'Passwords do not match.'
          : null,
      errorCode: () => null,
      errorMessage: () => null,
    );
    if (state.hasFieldErrors) return;

    state = state.copyWith(isLoading: true);
    try {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) {
        throw const AuthException(
          code: 'INVALID_TOKEN',
          message: 'Your session has expired. Please log in again.',
        );
      }
      await ref
          .read(settingsRepositoryProvider)
          .changePassword(
            token: token,
            oldPassword: state.oldPassword,
            newPassword: state.newPassword,
          );
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, isDone: true);
    } on AuthException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorCode: () => e.code,
        errorMessage: () => e.message,
      );
    }
  }
}
