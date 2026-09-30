import 'dart:async';

import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sends product events to AppAmbit Analytics and the debug console.
class EventLog {
  const EventLog();

  void log(String event, [Map<String, String> properties = const {}]) {
    debugPrint('[Analytics] $event $properties');
    unawaited(AppAmbitSdk.trackEvent(event, properties).onError((_, _) {}));
  }
}

final eventLogProvider = Provider<EventLog>((ref) => const EventLog());
