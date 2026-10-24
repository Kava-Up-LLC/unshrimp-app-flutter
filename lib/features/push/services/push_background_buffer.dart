import 'dart:convert';

import 'package:appambit_sdk_push_notifications/appambit_sdk_push_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key of the on-disk list of pushes received while the app was backgrounded or
/// killed, waiting to be stored on next open.
const pushBackgroundBufferKey = 'push_bg_buffer_v1';

/// Appends one push received in the background to the on-disk buffer.
///
/// Runs in the SDK's dedicated background isolate on Android (no UI, no Riverpod,
/// no auth token there), so it only touches SharedPreferences; the main isolate
/// drains it into `record_push` on the next open. Must stay a top-level
/// `vm:entry-point` function so release builds don't tree-shake it. Never
/// throws — a lost buffer write must not crash the isolate.
@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(PushNotificationData data) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(pushBackgroundBufferKey) ?? <String>[];
    list.add(
      jsonEncode({
        'title': data.title,
        'body': data.body,
        'open': data.data?['open'],
      }),
    );
    await prefs.setStringList(pushBackgroundBufferKey, list);
  } catch (_) {
    // Best effort: if the buffer write fails the push is simply not stored.
  }
}

/// Reads and clears the background buffer. Same key as [pushBackgroundHandler],
/// read from the main isolate on app open.
class PushBackgroundBuffer {
  const PushBackgroundBuffer();

  /// The buffered pushes, removed from disk as they are returned. Empty list
  /// when there is nothing (the common case).
  Future<List<Map<String, String?>>> drain() async {
    final prefs = await SharedPreferences.getInstance();
    // The background isolate wrote on its own SharedPreferences cache; reload so
    // this isolate sees those writes.
    await prefs.reload();
    final list = prefs.getStringList(pushBackgroundBufferKey) ?? const [];
    if (list.isEmpty) return const [];
    await prefs.remove(pushBackgroundBufferKey);
    return [
      for (final raw in list)
        if (jsonDecode(raw) case final Map<String, dynamic> m)
          {
            'title': m['title'] as String?,
            'body': m['body'] as String?,
            'open': m['open'] as String?,
          },
    ];
  }
}
