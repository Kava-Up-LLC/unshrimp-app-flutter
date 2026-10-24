import 'package:appambit_sdk_push_notifications/appambit_sdk_push_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/push_bridge.dart';

/// The running [PushBridge], overridden at startup when push is started.
/// Null when the app runs without an App Key (push never starts).
final pushBridgeProvider = Provider<PushBridge?>((ref) => null);

/// Pushes received while the app is in the foreground.
final pushForegroundProvider = StreamProvider<PushNotificationData>((ref) {
  final bridge = ref.watch(pushBridgeProvider);
  return bridge?.foreground ?? const Stream.empty();
});

/// Tapped pushes (including the cold-start tap), in order.
final pushOpenedProvider = StreamProvider<PushNotificationData>((ref) {
  final bridge = ref.watch(pushBridgeProvider);
  return bridge?.opened() ?? const Stream.empty();
});
