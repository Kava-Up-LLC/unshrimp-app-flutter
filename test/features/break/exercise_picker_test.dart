import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/break/services/exercise_picker.dart';
import 'package:unshrimp_app/features/exercises/models/exercise.dart';

import 'fakes.dart';

void main() {
  const shoulders = Exercise(zone: 'shoulders', title: 'S', steps: 's');
  const neckFreeA =
      Exercise(zone: 'neck', title: 'Neck Free A', steps: 'a', tier: 'free');
  const neckFreeB =
      Exercise(zone: 'neck', title: 'Neck Free B', steps: 'b', tier: 'free');
  const neckProA =
      Exercise(zone: 'neck', title: 'Neck Pro A', steps: 'c', tier: 'pro');
  const neckProB =
      Exercise(zone: 'neck', title: 'Neck Pro B', steps: 'd', tier: 'pro');

  test('picks a stretch of the user zone', () {
    expect(
      pickExercise([neckStretch, generalStretch], 'neck', isPro: true, random: Random(0)),
      same(neckStretch),
    );
  });

  test('a zone without stretches gets a general one', () {
    expect(
      pickExercise([neckStretch, generalStretch], 'wrists', isPro: true, random: Random(0)),
      same(generalStretch),
    );
  });

  test('without general stretches, any stretch will do', () {
    expect(
      pickExercise([shoulders], 'wrists', isPro: true, random: Random(0)),
      same(shoulders),
    );
  });

  test('Free never gets a pro stretch when the zone has a free one', () {
    for (var seed = 0; seed < 50; seed++) {
      final picked = pickExercise(
        [neckFreeA, neckProA, neckProB],
        'neck',
        isPro: false,
        random: Random(seed),
      );
      expect(picked.tier, 'free');
    }
  });

  test('Free rotates through every free stretch of the zone', () {
    final seen = <String>{};
    for (var seed = 0; seed < 50; seed++) {
      seen.add(
        pickExercise(
          [neckFreeA, neckFreeB, neckProA],
          'neck',
          isPro: false,
          random: Random(seed),
        ).title,
      );
    }
    expect(seen, {'Neck Free A', 'Neck Free B'});
  });

  test('a zone with no free stretch still gives Free the first one', () {
    for (var seed = 0; seed < 20; seed++) {
      expect(
        pickExercise([neckProA, neckProB], 'neck', isPro: false, random: Random(seed)),
        same(neckProA), // first of the zone, so Free always gets one
      );
    }
  });

  test('Pro reaches every stretch of the zone, free and pro alike', () {
    final seen = <String>{};
    for (var seed = 0; seed < 50; seed++) {
      seen.add(
        pickExercise(
          [neckFreeA, neckFreeB, neckProA],
          'neck',
          isPro: true,
          random: Random(seed),
        ).title,
      );
    }
    expect(seen, {'Neck Free A', 'Neck Free B', 'Neck Pro A'});
  });
}
