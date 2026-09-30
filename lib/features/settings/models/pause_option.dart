/// How long "Pause reminders" silences them.
enum PauseOption {
  oneDay('1 day', Duration(days: 1)),
  threeDays('3 days', Duration(days: 3)),
  oneWeek('1 week', Duration(days: 7)),
  twoWeeks('2 weeks', Duration(days: 14));

  const PauseOption(this.label, this.duration);

  final String label;
  final Duration duration;
}
