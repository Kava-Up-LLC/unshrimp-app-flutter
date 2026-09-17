/// Form state for the Log In screen.
class LogInState {
  const LogInState({
    this.email = '',
    this.password = '',
    this.isLoading = false,
    this.errorMessage,
    this.isAuthenticated = false,
  });

  final String email;
  final String password;
  final bool isLoading;
  final String? errorMessage;
  final bool isAuthenticated;

  LogInState copyWith({
    String? email,
    String? password,
    bool? isLoading,
    String? Function()? errorMessage,
    bool? isAuthenticated,
  }) {
    return LogInState(
      email: email ?? this.email,
      password: password ?? this.password,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}
