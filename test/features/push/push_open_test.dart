import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/push/models/push_open.dart';

void main() {
  test('each open key routes to its screen', () {
    expect(pushOpenLocation('history'), '/history');
    expect(pushOpenLocation('pro'), '/pro');
    expect(pushOpenLocation('report'), '/history?focus=report');
  });

  test('an unknown or missing key opens Home', () {
    expect(pushOpenLocation('whatever'), '/');
    expect(pushOpenLocation(null), '/');
  });
}
