import 'package:appambit_sdk_flutter/appambit_sdk_flutter_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_well_app/features/onboarding/models/question_option.dart';
import 'package:move_well_app/features/onboarding/models/question_type.dart';
import 'package:move_well_app/features/onboarding/repositories/fallback_onboarding_questions.dart';
import 'package:move_well_app/features/onboarding/repositories/onboarding_content_repository.dart';

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

  test('reads the CMS entries and sorts them by order', () async {
    _mockCms((call) async {
      expect(call.arguments['contentType'], 'onboarding_questions');
      return [
        {
          'data': {
            'key': 'work_schedule',
            'order': 2,
            'title': 'What are your work hours?',
            'subtitle': 'I only bug you inside them.',
            'type': 'time_range',
            'defaults': {'start': '09:00', 'end': '18:00'},
          },
        },
        {
          'key': 'tone',
          'order': 1,
          'title': 'How should the app treat you?',
          'subtitle': "This sets how fast your Spine Battery drains.",
          'type': 'single_choice',
          'options': [
            {'label': 'Gentle — Cheers you on.', 'value': 'gentle'},
          ],
        },
      ];
    });

    final questions = await const OnboardingContentRepository()
        .fetchQuestions();

    expect(questions.map((q) => q.key), ['tone', 'work_schedule']);
    expect(questions.first.type, QuestionType.singleChoice);
    expect(questions.first.options.single.value, 'gentle');
    expect(questions.last.type, QuestionType.timeRange);
    expect(questions.last.defaultStart, '09:00');
    expect(questions.last.defaultEnd, '18:00');
  });

  test('falls back to the local copy when the CMS returns nothing', () async {
    _mockCms((_) async => []);

    final questions = await const OnboardingContentRepository()
        .fetchQuestions();

    expect(questions, same(fallbackOnboardingQuestions));
  });

  test('falls back to the local copy when the CMS call fails', () async {
    _mockCms((_) async => throw PlatformException(code: 'NETWORK'));

    final questions = await const OnboardingContentRepository()
        .fetchQuestions();

    expect(questions, same(fallbackOnboardingQuestions));
  });

  test('fallback holds the four questions in order', () {
    expect(fallbackOnboardingQuestions.map((q) => q.key), [
      'sitting_hours',
      'work_schedule',
      'pain_zone',
      'tone',
    ]);
    expect(fallbackOnboardingQuestions[2].options.map((o) => o.value), [
      'neck',
      'shoulders',
      'lower_back',
      'wrists',
      'none',
    ]);
  });

  test('splits a combined CMS label into label and descriptor', () {
    final option = QuestionOption.fromJson({
      'label': 'Gentle — Cheers you on.',
      'value': 'gentle',
    });

    expect(option.label, 'Gentle');
    expect(option.description, 'Cheers you on.');
    expect(option.value, 'gentle');
  });

  test('keeps a plain label and prefers an explicit description', () {
    expect(
      QuestionOption.fromJson({'label': 'Neck', 'value': 'neck'}).description,
      isNull,
    );
    final option = QuestionOption.fromJson({
      'label': 'Direct',
      'value': 'direct',
      'description': 'Reminds you, no fluff.',
    });
    expect(option.label, 'Direct');
    expect(option.description, 'Reminds you, no fluff.');
  });
}
