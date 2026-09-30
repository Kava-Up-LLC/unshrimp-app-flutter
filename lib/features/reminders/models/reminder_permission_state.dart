/// State of the first-run "why notifications" screen.
class ReminderPermissionState {
  const ReminderPermissionState({this.isBusy = false, this.isDone = false});

  /// The OS prompt or the reschedule after it is running.
  final bool isBusy;

  /// The user answered; the view moves on to Home.
  final bool isDone;

  ReminderPermissionState copyWith({bool? isBusy, bool? isDone}) =>
      ReminderPermissionState(
        isBusy: isBusy ?? this.isBusy,
        isDone: isDone ?? this.isDone,
      );
}
