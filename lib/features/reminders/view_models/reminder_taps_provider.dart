import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/reminder_notifications.dart';

/// Payloads of reminders tapped while the app is running.
final reminderTapsProvider = StreamProvider<String?>(
  (ref) => ref.read(reminderNotificationsProvider).taps,
);
