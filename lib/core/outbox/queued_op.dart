/// One mutation the app owes AppAmbit, persisted so it survives a kill and a
/// reboot.
///
/// [opId] is minted when the user ACTS — taps "Survived", or a reconcile run
/// decides a set of reminders expired — NOT when the flush runs. Every retry of
/// the same operation replays under this one id, so the server records it once
/// (`applied_ops`) and a replayed flush is harmless. If the flush minted a new
/// id each time, the dedup would be decoration and a break would double-count.
///
/// [body] never carries the auth token: the flusher injects a fresh token at
/// send time, so a refreshed session is always used and a stale token is never
/// frozen into the queue. [opId] is sent alongside the body, not inside it.
class QueuedOp {
  const QueuedOp({
    required this.opId,
    required this.function,
    required this.body,
    required this.userId,
    required this.createdAt,
  });

  final String opId;
  final String function;
  final Map<String, dynamic> body;
  final String userId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'op_id': opId,
    'function': function,
    'body': body,
    'user_id': userId,
    'created_at': createdAt.toIso8601String(),
  };

  /// Decodes one stored op, or null when the value is malformed or old-shape —
  /// a bad entry is dropped, never thrown, so an upgrade can't crash on it.
  static QueuedOp? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final opId = raw['op_id'];
    final function = raw['function'];
    final body = raw['body'];
    final userId = raw['user_id'];
    final createdAt = DateTime.tryParse(raw['created_at']?.toString() ?? '');
    if (opId is! String ||
        function is! String ||
        body is! Map ||
        userId is! String ||
        createdAt == null) {
      return null;
    }
    return QueuedOp(
      opId: opId,
      function: function,
      body: Map<String, dynamic>.from(body),
      userId: userId,
      createdAt: createdAt,
    );
  }
}
