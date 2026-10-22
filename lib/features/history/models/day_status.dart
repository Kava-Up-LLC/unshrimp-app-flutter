/// How a single day reads on the History screen's week card.
enum DayStatus {
  /// Reached the daily goal.
  met,

  /// Took at least one break but fell short of the goal.
  partial,

  /// No breaks at all.
  missed,

  /// A day the user does not work: shown as rest, skipped by the streak.
  rest,
}
