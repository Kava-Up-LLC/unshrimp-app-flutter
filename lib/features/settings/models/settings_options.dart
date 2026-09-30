/// Values the user can pick in Settings. `update_settings` enforces the same
/// ranges on the server.
class SettingsOptions {
  const SettingsOptions._();

  static const reminderIntervals = [30, 45, 60, 90];
  static const dailyGoals = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
}
