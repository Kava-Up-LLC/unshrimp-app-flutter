import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/push/services/push_bootstrap.dart';
import '../../features/push/services/push_notifications.dart';
import '../../features/push/view_models/push_providers.dart';
import '../../features/update_gate/view_models/version_gate.dart';
import 'missing_app_key_app.dart';
import 'unshrimp_app.dart';

/// Initializes environment, AppAmbit and Riverpod, then launches the app.
class AppBootstrap {
  const AppBootstrap._();

  /// The App Key is supplied at build time, never bundled:
  /// `flutter run --dart-define=APPAMBIT_APP_KEY=<key>`
  static const _appKey = String.fromEnvironment('APPAMBIT_APP_KEY');

  static Future<void> run() async {
    WidgetsFlutterBinding.ensureInitialized();

    // No key means there is no backend to reach: show a plain screen instead of
    // starting the SDK (or crashing on an empty key).
    if (_appKey.isEmpty) {
      runApp(const MissingAppKeyApp());
      return;
    }

    // Remote Config is fetched during start(), so enable it first.
    await AppAmbitSdk.enableConfig();
    // start() installs the SDK's own FlutterError.onError,
    // PlatformDispatcher.instance.onError and isolate error listener, all
    // routing to Crash Reporting. We deliberately do NOT install our own — that
    // would double-report every framework/async error. Handled errors are sent
    // explicitly with AppAmbitSdk.logError where we catch them.
    await AppAmbitSdk.start(appKey: _appKey);

    // Push starts right after the core SDK and only with an App Key (the empty
    // key is handled above). The bridge feeds foreground banners and taps.
    final pushBridge = await startPush(_appKey, const PushNotifications());

    // Kill switch: gate a build below min_supported_version before anything
    // else. Permissive by design — any doubt lets the app run (see
    // isUpdateRequired).
    final updateRequired = await isUpdateRequired();

    runApp(
      ProviderScope(
        overrides: [pushBridgeProvider.overrideWithValue(pushBridge)],
        child: UnshrimpApp(updateRequired: updateRequired),
      ),
    );
  }
}
