import 'package:move_well_app/features/auth/models/auth_exception.dart';
import 'package:move_well_app/features/settings/models/user_settings.dart';
import 'package:move_well_app/features/settings/repositories/settings_repository.dart';

const testSettings = UserSettings(
  activeStart: '09:00',
  activeEnd: '18:00',
  reminderIntervalMin: 60,
  graceWindowMin: 60,
  dailyGoal: 5,
  tone: 'direct',
  painZone: 'neck',
  quietMode: false,
  pausedUntil: null,
);

class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({this.error, this.fetchError});

  /// Thrown by [update] and [changePassword].
  AuthException? error;

  /// Thrown by [fetch].
  final AuthException? fetchError;

  final updates = <Map<String, Object?>>[];
  final passwordChanges = <({String old, String next})>[];

  @override
  Future<UserSettings> fetch(String token) async {
    if (fetchError != null) throw fetchError!;
    return testSettings;
  }

  @override
  Future<UserSettings> update(
    String token,
    Map<String, Object?> settings,
  ) async {
    updates.add(settings);
    if (error != null) throw error!;
    return UserSettings(
      activeStart: '09:00',
      activeEnd: '18:00',
      reminderIntervalMin: 60,
      graceWindowMin: 60,
      dailyGoal: 5,
      tone: settings['tone']?.toString() ?? 'direct',
      painZone: 'neck',
      quietMode: settings['quiet_mode'] == true,
      pausedUntil: null,
    );
  }

  @override
  Future<void> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  }) async {
    passwordChanges.add((old: oldPassword, next: newPassword));
    if (error != null) throw error!;
  }
}
