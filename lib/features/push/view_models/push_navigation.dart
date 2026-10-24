import 'package:appambit_sdk_push_notifications/appambit_sdk_push_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/analytics/event_log.dart';
import '../models/push_open.dart';

/// Opens a tapped push: logs `push_opened` with its open key and navigates the
/// same way the reminder taps do. The push's screens are nested under Home, so
/// Back returns Home. Shared by the opened listener and the foreground banner.
void openPush(WidgetRef ref, GoRouter router, PushNotificationData data) {
  final open = data.data?['open'];
  ref.read(eventLogProvider).log('push_opened', {'open': open ?? ''});
  router.go(pushOpenLocation(open));
}
