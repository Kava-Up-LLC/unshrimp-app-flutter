import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/exercises/models/exercise.dart';

void main() {
  test('parses tier free and pro', () {
    expect(Exercise.fromCms({'tier': 'free'}).tier, 'free');
    expect(Exercise.fromCms({'tier': 'pro'}).tier, 'pro');
  });

  test('a missing or unrecognized tier is pro', () {
    expect(Exercise.fromCms({}).tier, 'pro');
    expect(Exercise.fromCms({'tier': ''}).tier, 'pro');
    expect(Exercise.fromCms({'tier': 'gold'}).tier, 'pro');
  });

  test('reads tier nested under data', () {
    expect(
      Exercise.fromCms({
        'data': {'tier': 'free', 'zone': 'neck'},
      }).tier,
      'free',
    );
  });
}
