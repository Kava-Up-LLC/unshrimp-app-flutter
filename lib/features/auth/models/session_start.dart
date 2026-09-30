import 'session_status.dart';

/// Result of checking the stored session at launch, and where an
/// authenticated user goes next.
class SessionStart {
  const SessionStart(this.status, {this.location});

  final SessionStatus status;

  /// Home, or the break when a tapped reminder launched the app. Null when
  /// [status] is unauthenticated.
  final String? location;
}
