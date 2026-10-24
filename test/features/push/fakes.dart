import 'package:appambit_sdk_push_notifications/appambit_sdk_push_notifications.dart';
import 'package:unshrimp_app/features/push/services/push_notifications.dart';

/// Records what the app asks of the push SDK, without touching a platform.
class FakePushNotifications implements PushNotifications {
  FakePushNotifications({this.enabled = true, this.throwOnRead = false});

  int startCalls = 0;
  int registerCalls = 0;
  int registerIfPermittedCalls = 0;
  bool enabled;
  bool throwOnRead;
  bool hasPermission = true;
  bool? lastSetEnabled;
  PushNotificationListener? foregroundListener;
  PushNotificationListener? openedListener;
  PushNotificationListener? backgroundHandler;

  @override
  Future<void> start() async => startCalls++;

  @override
  Future<void> register() async => registerCalls++;

  @override
  Future<void> registerIfPermitted() async {
    registerIfPermittedCalls++;
    if (hasPermission) registerCalls++;
  }

  @override
  void onForeground(PushNotificationListener listener) =>
      foregroundListener = listener;

  @override
  void onOpened(PushNotificationListener listener) =>
      openedListener = listener;

  @override
  Future<void> setBackgroundHandler(PushNotificationListener handler) async =>
      backgroundHandler = handler;

  @override
  Future<bool> isEnabled() async {
    if (throwOnRead) throw Exception('sdk unavailable');
    return enabled;
  }

  @override
  Future<void> setEnabled(bool value) async {
    lastSetEnabled = value;
    enabled = value;
  }
}
