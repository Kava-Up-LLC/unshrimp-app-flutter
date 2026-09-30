import 'package:flutter_test/flutter_test.dart';
import 'package:move_well_app/features/reminders/models/reminder_payload.dart';

void main() {
  test('round-trips zone and key', () {
    final decoded = ReminderPayload.decode(
      const ReminderPayload(zone: 'neck', key: 'd1-0').encode(),
    );
    expect((decoded.zone, decoded.key), ('neck', 'd1-0'));
  });

  test('the debug reminder has a key and no zone', () {
    final decoded = ReminderPayload.decode(
      const ReminderPayload(key: 'o1').encode(),
    );
    expect((decoded.zone, decoded.key), (null, 'o1'));
  });

  test('an older plain-zone payload still gives the zone', () {
    final decoded = ReminderPayload.decode('shoulders');
    expect((decoded.zone, decoded.key), ('shoulders', null));
  });

  test('empty or missing payload', () {
    for (final raw in [null, '']) {
      final decoded = ReminderPayload.decode(raw);
      expect((decoded.zone, decoded.key), (null, null));
    }
  });
}
