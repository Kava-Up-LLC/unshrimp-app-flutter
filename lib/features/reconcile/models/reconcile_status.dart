/// How a reconciliation run ended.
enum ReconcileStatus {
  /// No expired reminders to count.
  nothingPending,

  /// Expired reminders existed, but the server counted none (outside the
  /// active window or paused). Nothing was marked.
  notCounted,

  /// The expired reminders were counted and marked.
  counted,
}
