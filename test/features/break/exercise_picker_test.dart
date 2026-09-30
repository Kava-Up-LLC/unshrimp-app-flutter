import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:move_well_app/features/break/services/exercise_picker.dart';
import 'package:move_well_app/features/exercises/models/exercise.dart';

import 'fakes.dart';

void main() {
  const shoulders = Exercise(zone: 'shoulders', title: 'S', steps: 's');

  test('picks a stretch of the user zone', () {
    expect(
      pickExercise([neckStretch, generalStretch], 'neck', Random(0)),
      same(neckStretch),
    );
  });

  test('a zone without stretches gets a general one', () {
    expect(
      pickExercise([neckStretch, generalStretch], 'wrists', Random(0)),
      same(generalStretch),
    );
  });

  test('without general stretches, any stretch will do', () {
    expect(pickExercise([shoulders], 'wrists', Random(0)), same(shoulders));
  });
}
