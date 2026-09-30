/// A time of day at which a daily reminder fires.
class ReminderSlot {
  const ReminderSlot({required this.hour, required this.minute});

  /// [minuteOfDay] is wrapped into 0..1439.
  factory ReminderSlot.fromMinuteOfDay(int minuteOfDay) {
    final wrapped = minuteOfDay % Duration.minutesPerDay;
    return ReminderSlot(hour: wrapped ~/ 60, minute: wrapped % 60);
  }

  final int hour;
  final int minute;

  @override
  bool operator ==(Object other) =>
      other is ReminderSlot && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
