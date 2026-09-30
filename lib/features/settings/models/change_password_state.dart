/// Form state for the Change password screen, including per-field client
/// errors.
class ChangePasswordState {
  const ChangePasswordState({
    this.oldPassword = '',
    this.newPassword = '',
    this.confirmPassword = '',
    this.oldPasswordError,
    this.newPasswordError,
    this.confirmPasswordError,
    this.isLoading = false,
    this.errorCode,
    this.errorMessage,
    this.isDone = false,
  });

  final String oldPassword;
  final String newPassword;
  final String confirmPassword;
  final String? oldPasswordError;
  final String? newPasswordError;
  final String? confirmPasswordError;
  final bool isLoading;

  /// Backend error code, e.g. `WRONG_PASSWORD` or `INVALID_TOKEN`.
  final String? errorCode;
  final String? errorMessage;
  final bool isDone;

  bool get hasFieldErrors =>
      oldPasswordError != null ||
      newPasswordError != null ||
      confirmPasswordError != null;

  ChangePasswordState copyWith({
    String? oldPassword,
    String? newPassword,
    String? confirmPassword,
    String? Function()? oldPasswordError,
    String? Function()? newPasswordError,
    String? Function()? confirmPasswordError,
    bool? isLoading,
    String? Function()? errorCode,
    String? Function()? errorMessage,
    bool? isDone,
  }) {
    return ChangePasswordState(
      oldPassword: oldPassword ?? this.oldPassword,
      newPassword: newPassword ?? this.newPassword,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      oldPasswordError: oldPasswordError != null
          ? oldPasswordError()
          : this.oldPasswordError,
      newPasswordError: newPasswordError != null
          ? newPasswordError()
          : this.newPasswordError,
      confirmPasswordError: confirmPasswordError != null
          ? confirmPasswordError()
          : this.confirmPasswordError,
      isLoading: isLoading ?? this.isLoading,
      errorCode: errorCode != null ? errorCode() : this.errorCode,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      isDone: isDone ?? this.isDone,
    );
  }
}
