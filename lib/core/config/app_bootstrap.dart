import 'dart:io' show Platform;

import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/update_gate/view_models/version_gate.dart';
import 'move_well_app.dart';

/// Initializes environment, AppAmbit and Riverpod, then launches the app.
class AppBootstrap {
  const AppBootstrap._();

  static Future<void> run() async {
    WidgetsFlutterBinding.ensureInitialized();

    await dotenv.load(fileName: '.env');
    // Remote Config is fetched during start(), so enable it first.
    await AppAmbitSdk.enableConfig();
    // start() installs the SDK's own FlutterError.onError,
    // PlatformDispatcher.instance.onError and isolate error listener, all
    // routing to Crash Reporting. We deliberately do NOT install our own — that
    // would double-report every framework/async error. Handled errors are sent
    // explicitly with AppAmbitSdk.logError where we catch them.
    // One AppAmbit app per platform: pick the key for the OS we're running on.
    // Falls back to the legacy single key so an older .env keeps working.
    final appKey = (Platform.isAndroid
            ? dotenv.env['APPAMBIT_APP_KEY_ANDROID']
            : dotenv.env['APPAMBIT_APP_KEY_IOS']) ??
        dotenv.env['APPAMBIT_APP_KEY'];
    await AppAmbitSdk.start(appKey: appKey!);

    // Kill switch: gate a build below min_supported_version before anything
    // else. Permissive by design — any doubt lets the app run (see
    // isUpdateRequired).
    final updateRequired = await isUpdateRequired();

    runApp(ProviderScope(child: MoveWellApp(updateRequired: updateRequired)));
  }
}
