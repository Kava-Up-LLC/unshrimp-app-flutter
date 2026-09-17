/// Form state for the Sign Up screen, including per-field client errors.
class SignUpState {
  const SignUpState({
    this.name = '',
    this.email = '',
    this.password = '',
    this.confirmPassword = '',
    this.nameError,
    this.emailError,
    this.passwordError,
    this.confirmPasswordError,
    this.isLoading = false,
    this.errorMessage,
    this.isAuthenticated = false,
  });

  final String name;
  final String email;
  final String password;
  final String confirmPassword;
  final String? nameError;
  final String? emailError;
  final String? passwordError;
  final String? confirmPasswordError;
  final bool isLoading;
  final String? errorMessage;
  final bool isAuthenticated;

  bool get hasFieldErrors =>
      nameError != null ||
      emailError != null ||
      passwordError != null ||
      confirmPasswordError != null;

  SignUpState copyWith({
    String? name,
    String? email,
    String? password,
    String? confirmPassword,
    String? Function()? nameError,
    String? Function()? emailError,
    String? Function()? passwordError,
    String? Function()? confirmPasswordError,
    bool? isLoading,
    String? Function()? errorMessage,
    bool? isAuthenticated,
  }) {
    return SignUpState(
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      nameError: nameError != null ? nameError() : this.nameError,
      emailError: emailError != null ? emailError() : this.emailError,
      passwordError: passwordError != null
          ? passwordError()
          : this.passwordError,
      confirmPasswordError: confirmPasswordError != null
          ? confirmPasswordError()
          : this.confirmPasswordError,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}
