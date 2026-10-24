import 'dart:async';

import 'package:appambit_sdk_push_notifications/appambit_sdk_push_notifications.dart';

/// Carries push events from the SDK's global listeners into the widget tree.
/// Created at startup (only when there is an App Key), so a tap that launched
/// the app on a cold start is held until the UI subscribes and can navigate.
class PushBridge {
  final _foreground = StreamController<PushNotificationData>.broadcast();
  final _opened = StreamController<PushNotificationData>.broadcast();
  PushNotificationData? _pendingOpen;
  PushNotificationData? _launchOpen;

  /// The tap that launched the app on a cold start (before the UI subscribed),
  /// or null. The session gate reads it so the launch lands on the push's
  /// screen instead of Home. Unlike [opened], reading it does not consume it.
  PushNotificationData? get launchOpen => _launchOpen;

  /// Pushes that arrived while the app was open.
  Stream<PushNotificationData> get foreground => _foreground.stream;

  /// Tapped pushes: the cold-start tap (if any) first, then the live taps.
  Stream<PushNotificationData> opened() async* {
    if (_pendingOpen case final pending?) {
      _pendingOpen = null;
      yield pending;
    }
    yield* _opened.stream;
  }

  void handleForeground(PushNotificationData data) => _foreground.add(data);

  void handleOpened(PushNotificationData data) {
    // Remember the tap regardless of listener timing: on a launch/relaunch the
    // SDK may deliver it on the live stream (listener already attached) a beat
    // before the session gate runs, so the gate still needs to find it here to
    // route to the push's screen instead of falling through to Home.
    _launchOpen = data;
    if (_opened.hasListener) {
      _opened.add(data);
    } else {
      // Tapped before the UI subscribed (cold start): deliver on first listen.
      _pendingOpen = data;
    }
  }

  void dispose() {
    unawaited(_foreground.close());
    unawaited(_opened.close());
  }
}
