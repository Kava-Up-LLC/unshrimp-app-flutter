/// Values the user can pick in Settings. `update_settings` enforces the same
/// ranges on the server.
class SettingsOptions {
  const SettingsOptions._();

  static const reminderIntervals = [30, 45, 60, 90];
  static const dailyGoals = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

  /// Same values and labels as the onboarding tone question.
  static const tones = ['gentle', 'direct', 'no_mercy'];
  static const toneLabels = {
    'gentle': 'Gentle — Cheers you on.',
    'direct': 'Direct — Reminds you, no fluff.',
    'no_mercy': 'No mercy — Roasts you when you slack.',
  };

  /// Short label for the Settings row value.
  static String toneShort(String tone) => switch (tone) {
    'gentle' => 'Gentle',
    'direct' => 'Direct',
    'no_mercy' => 'No mercy',
    _ => tone,
  };
}
