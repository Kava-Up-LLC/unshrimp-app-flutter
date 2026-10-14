import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/update_gate/view_models/version_gate.dart';

void main() {
  // The running build; tests inject it so no real PackageInfo is needed.
  Future<String> Function() version(String v) => () => Future.value(v);

  // A Remote Config reader that returns a fixed value for the min key.
  Future<String?> Function(String) config(String? value) =>
      (_) async => value;

  group('isVersionBelow', () {
    test('strictly lower is below', () {
      expect(isVersionBelow('1.0.0', '1.2.0'), isTrue);
      expect(isVersionBelow('1.9.0', '1.10.0'), isTrue);
      expect(isVersionBelow('0.9.9', '1.0.0'), isTrue);
    });

    test('equal is not below', () {
      expect(isVersionBelow('1.2.0', '1.2.0'), isFalse);
    });

    test('higher is not below', () {
      expect(isVersionBelow('2.0.0', '1.9.9'), isFalse);
      expect(isVersionBelow('1.10.0', '1.9.0'), isFalse);
    });

    test('build and pre-release suffixes are ignored', () {
      expect(isVersionBelow('1.0.0+42', '1.0.0'), isFalse);
      expect(isVersionBelow('1.0.0-beta', '1.1.0'), isTrue);
    });

    test('unparseable either side is never below (permissive)', () {
      expect(isVersionBelow('abc', '1.0.0'), isFalse);
      expect(isVersionBelow('1.0.0', 'not-a-version'), isFalse);
      expect(isVersionBelow('', '1.0.0'), isFalse);
    });
  });

  group('isUpdateRequired', () {
    test('below the minimum blocks', () async {
      expect(
        await isUpdateRequired(
          readConfig: config('1.2.0'),
          currentVersion: version('1.0.0'),
        ),
        isTrue,
      );
    });

    test('equal to the minimum runs', () async {
      expect(
        await isUpdateRequired(
          readConfig: config('1.0.0'),
          currentVersion: version('1.0.0'),
        ),
        isFalse,
      );
    });

    test('above the minimum runs', () async {
      expect(
        await isUpdateRequired(
          readConfig: config('1.0.0'),
          currentVersion: version('2.3.1'),
        ),
        isFalse,
      );
    });

    test('missing key runs', () async {
      expect(
        await isUpdateRequired(
          readConfig: config(null),
          currentVersion: version('1.0.0'),
        ),
        isFalse,
      );
    });

    test('empty key runs', () async {
      expect(
        await isUpdateRequired(
          readConfig: config('   '),
          currentVersion: version('1.0.0'),
        ),
        isFalse,
      );
    });

    test('malformed key runs', () async {
      expect(
        await isUpdateRequired(
          readConfig: config('v1,2,3'),
          currentVersion: version('1.0.0'),
        ),
        isFalse,
      );
    });

    test('a failed fetch runs', () async {
      expect(
        await isUpdateRequired(
          readConfig: (_) => Future.error(Exception('transport')),
          currentVersion: version('1.0.0'),
        ),
        isFalse,
      );
    });
  });

  group('updateStoreUrl', () {
    test('returns a trimmed non-empty url', () async {
      expect(
        await updateStoreUrl(readConfig: config('  https://store/app  ')),
        'https://store/app',
      );
    });

    test('null for missing, empty or failed', () async {
      expect(await updateStoreUrl(readConfig: config(null)), isNull);
      expect(await updateStoreUrl(readConfig: config('')), isNull);
      expect(
        await updateStoreUrl(
          readConfig: (_) => Future.error(Exception('transport')),
        ),
        isNull,
      );
    });
  });
}
