import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/break/models/break_args.dart';
import 'package:unshrimp_app/features/break/models/break_source.dart';

void main() {
  test('a reminder payload becomes the break route and back', () {
    final args = BreakArgs.fromReminderPayload('lower_back');

    expect(args.location, '/break?source=reminder&zone=lower_back');
    expect(BreakArgs.fromUri(Uri.parse(args.location)), args);
  });

  test('an empty payload leaves the zone to the settings', () {
    final args = BreakArgs.fromReminderPayload('');

    expect(args.zone, isNull);
    expect(args.location, '/break?source=reminder');
  });

  test('Home opens a break without a zone', () {
    expect(
      const BreakArgs(source: BreakSource.home).location,
      '/break?source=home',
    );
  });

  test('a keyed reminder payload carries its key into the route', () {
    final args = BreakArgs.fromReminderPayload('{"zone":"neck","key":"d1-0"}');

    expect(args.zone, 'neck');
    expect(args.reminderKey, 'd1-0');
    expect(args.location, '/break?source=reminder&zone=neck&key=d1-0');
    expect(BreakArgs.fromUri(Uri.parse(args.location)), args);
  });
}
