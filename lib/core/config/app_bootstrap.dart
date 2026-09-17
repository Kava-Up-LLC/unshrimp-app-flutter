import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'move_well_app.dart';

/// Initializes environment, AppAmbit and Riverpod, then launches the app.
class AppBootstrap {
  const AppBootstrap._();

  static Future<void> run() async {
    WidgetsFlutterBinding.ensureInitialized();

    await dotenv.load(fileName: '.env');
    await AppAmbitSdk.start(appKey: dotenv.env['APPAMBIT_APP_KEY']!);

    runApp(const ProviderScope(child: MoveWellApp()));
  }
}
