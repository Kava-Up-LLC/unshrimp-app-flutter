import 'push_background_buffer.dart';
import 'push_bridge.dart';
import 'push_notifications.dart';

/// Starts the push module right after the core SDK, and only when there is an
/// App Key. Returns the [PushBridge] that feeds the UI, or null when there is
/// no key — in which case push never starts.
Future<PushBridge?> startPush(String appKey, PushNotifications push) async {
  if (appKey.isEmpty) return null;
  await push.start();
  final bridge = PushBridge();
  push.onForeground(bridge.handleForeground);
  push.onOpened(bridge.handleOpened);
  // Android: buffer pushes that arrive while backgrounded/killed so the next
  // open stores them (iOS no-ops here). Flushed by pushCenterRecorderProvider.
  await push.setBackgroundHandler(pushBackgroundHandler);
  return bridge;
}
