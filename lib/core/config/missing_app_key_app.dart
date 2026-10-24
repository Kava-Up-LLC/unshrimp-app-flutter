import 'package:flutter/material.dart';

/// Shown when no `APPAMBIT_APP_KEY` compile-time define was passed: there is no
/// backend to reach, so the app does not start the SDK and says how to supply
/// the key.
class MissingAppKeyApp extends StatelessWidget {
  const MissingAppKeyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Missing App Key. Run with --dart-define=APPAMBIT_APP_KEY=...',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
