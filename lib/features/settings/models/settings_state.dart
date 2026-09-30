import '../../auth/models/auth_exception.dart';
import 'user_settings.dart';

/// Settings screen state: the user's row plus the status of the last change.
class SettingsState {
  const SettingsState({
    required this.settings,
    this.isSaving = false,
    this.error,
  });

  final UserSettings settings;

  /// An `update_settings` call is running; every control is disabled.
  final bool isSaving;
  final AuthException? error;

  SettingsState copyWith({
    UserSettings? settings,
    bool? isSaving,
    AuthException? Function()? error,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      isSaving: isSaving ?? this.isSaving,
      error: error != null ? error() : this.error,
    );
  }
}
