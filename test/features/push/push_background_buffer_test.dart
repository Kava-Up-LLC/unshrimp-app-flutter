import 'package:appambit_sdk_push_notifications/appambit_sdk_push_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unshrimp_app/features/push/services/push_background_buffer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('handler buffers each push; drain returns them then clears', () async {
    await pushBackgroundHandler(
      const PushNotificationData(title: 'A', body: 'b1', data: {'open': 'report'}),
    );
    await pushBackgroundHandler(const PushNotificationData(title: 'B', body: 'b2'));

    const buffer = PushBackgroundBuffer();
    expect(await buffer.drain(), [
      {'title': 'A', 'body': 'b1', 'open': 'report'},
      {'title': 'B', 'body': 'b2', 'open': null},
    ]);
    // Cleared after draining.
    expect(await buffer.drain(), isEmpty);
  });

  test('drain on an empty buffer is empty', () async {
    expect(await const PushBackgroundBuffer().drain(), isEmpty);
  });
}
