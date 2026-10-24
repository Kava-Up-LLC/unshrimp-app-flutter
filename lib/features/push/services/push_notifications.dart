import 'package:appambit_sdk_push_notifications/appambit_sdk_push_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin instance wrapper over the static [PushNotificationsSdk], so callers can
/// be handed a fake in tests.
class PushNotifications {
  const PushNotifications();

  Future<void> start() => PushNotificationsSdk.start();

  /// Registers the device for push. Called only after the OS notification
  /// permission was already granted in onboarding: the SDK then resolves
  /// without showing a second prompt.
  Future<void> register() =>
      PushNotificationsSdk.requestNotificationPermission();

  /// Registers for push only when the OS permission is already granted, so it
  /// never prompts. Used on login, where onboarding won't run again (e.g. a
  /// returning user on a new device) and we must not ask a second time.
  Future<void> registerIfPermitted() async {
    if (await PushNotificationsSdk.hasNotificationPermission()) {
      await PushNotificationsSdk.requestNotificationPermission();
    }
  }

  void onForeground(PushNotificationListener listener) =>
      PushNotificationsSdk.setForegroundListener(listener);

  void onOpened(PushNotificationListener listener) =>
      PushNotificationsSdk.setOpenedListener(listener);

  /// Registers the background-received handler (Android only; a no-op on iOS,
  /// whose background push runs in a native extension). [handler] must be a
  /// top-level `vm:entry-point` function — it runs in a separate isolate.
  Future<void> setBackgroundHandler(PushNotificationListener handler) =>
      PushNotificationsSdk.Android.setBackgroundHandler(handler);

  /// The SDK-level "Tips and news" toggle (independent of reminders and of the
  /// OS permission).
  Future<bool> isEnabled() => PushNotificationsSdk.isNotificationsEnabled();

  Future<void> setEnabled(bool enabled) =>
      PushNotificationsSdk.setNotificationsEnabled(enabled);
}

final pushNotificationsProvider = Provider<PushNotifications>(
  (ref) => const PushNotifications(),
);
