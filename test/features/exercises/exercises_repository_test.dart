import 'dart:io';

import 'package:appambit_sdk_flutter/appambit_sdk_flutter_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_well_app/features/exercises/repositories/exercises_repository.dart';
import 'package:move_well_app/features/exercises/repositories/fallback_exercises.dart';

const _cms = MethodChannel('com.appambit/cms');

void _mockCms(Future<Object?> Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_cms, handler);
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_cms, null),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Tests don't register the native plugin; route the SDK through the channel
  // so each test can mock `com.appambit/cms`.
  MethodChannelAppAmbitSdkFlutter.createAndRegister();

  test('reads the CMS entries', () async {
    _mockCms((call) async {
      expect(call.arguments['contentType'], 'exercises');
      return [
        {
          'data': {
            'zone': 'neck',
            'title': 'Neck rolls',
            'steps': 'Roll your head.',
            'image_url': 'https://cdn.example.com/neck-rolls.gif',
          },
        },
      ];
    });

    final exercises = await const ExercisesRepository().fetchExercises();

    expect(exercises.single.zone, 'neck');
    expect(exercises.single.title, 'Neck rolls');
    expect(exercises.single.steps, 'Roll your head.');
    expect(exercises.single.mediaUrl, 'https://cdn.example.com/neck-rolls.gif');
  });

  test('attaches the bundled image to CMS entries by title', () async {
    _mockCms(
      (_) async => [
        for (final e in fallbackExercises)
          {
            'data': {'zone': e.zone, 'title': e.title, 'steps': e.steps},
          },
      ],
    );

    final exercises = await const ExercisesRepository().fetchExercises();

    expect(
      exercises.map((e) => e.assetPath),
      fallbackExercises.map((e) => e.assetPath),
    );
  });

  test('falls back to the local copy when the CMS call fails', () async {
    _mockCms((_) async => throw PlatformException(code: 'NETWORK'));

    final exercises = await const ExercisesRepository().fetchExercises();

    expect(exercises, same(fallbackExercises));
  });

  test('fallback covers every zone in the dataset', () {
    for (final zone in ['neck', 'shoulders', 'lower_back', 'none']) {
      expect(fallbackExercises.where((e) => e.zone == zone), isNotEmpty);
    }
  });

  test('every fallback exercise has a bundled image', () {
    for (final exercise in fallbackExercises) {
      final path = exercise.assetPath;
      expect(path, isNotNull, reason: exercise.title);
      expect(File(path!).existsSync(), isTrue, reason: path);
    }
  });
}
