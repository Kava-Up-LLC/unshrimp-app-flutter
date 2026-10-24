import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/core/config/flavor.dart';

void main() {
  test('only the dev flavor is dev; absent or unknown reads as prod', () {
    expect(isDevFlavor('dev'), isTrue);
    expect(isDevFlavor('prod'), isFalse);
    expect(isDevFlavor(''), isFalse); // no --dart-define=FLAVOR
    expect(isDevFlavor('DEV'), isFalse); // exact match only
  });
}
