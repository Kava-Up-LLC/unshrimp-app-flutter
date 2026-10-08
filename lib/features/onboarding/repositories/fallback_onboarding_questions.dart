import '../models/onboarding_question.dart';
import '../models/question_option.dart';
import '../models/question_type.dart';

/// Local copy of the CMS `onboarding_questions` content, used when the CMS
/// can't be reached. Keep it in sync with the CMS entries.
const fallbackOnboardingQuestions = [
  OnboardingQuestion(
    key: 'sitting_hours',
    order: 1,
    title: 'How many hours a day do you sit?',
    subtitle: 'So I know how often to nudge you.',
    type: QuestionType.singleChoice,
    options: [
      QuestionOption(label: 'Under 4 hours', value: '0-4'),
      QuestionOption(label: '4 to 8 hours', value: '4-8'),
      QuestionOption(label: '8 to 12 hours', value: '8-12'),
      QuestionOption(label: 'Over 12 hours', value: '12+'),
    ],
  ),
  OnboardingQuestion(
    key: 'work_schedule',
    order: 2,
    title: 'What are your work hours?',
    subtitle: 'I only bug you inside them.',
    type: QuestionType.timeRange,
    defaultStart: '09:00',
    defaultEnd: '18:00',
  ),
  OnboardingQuestion(
    key: 'pain_zone',
    order: 3,
    title: 'Where does it hurt most?',
    subtitle: 'I pick your exercises from this.',
    type: QuestionType.singleChoice,
    options: [
      QuestionOption(label: 'Neck', value: 'neck'),
      QuestionOption(label: 'Shoulders', value: 'shoulders'),
      QuestionOption(label: 'Lower back', value: 'lower_back'),
      QuestionOption(label: 'Wrists', value: 'wrists'),
      QuestionOption(label: 'Nothing yet', value: 'none'),
    ],
  ),
  OnboardingQuestion(
    key: 'tone',
    order: 4,
    title: 'How should the app treat you?',
    subtitle: "This sets how fast your Spine Battery drains.",
    type: QuestionType.singleChoice,
    options: [
      QuestionOption(
        label: 'Gentle',
        value: 'gentle',
        description: 'Cheers you on.',
      ),
      QuestionOption(
        label: 'Direct',
        value: 'direct',
        description: 'Reminds you, no fluff.',
      ),
      QuestionOption(
        label: 'No mercy',
        value: 'no_mercy',
        description: 'Roasts you when you slack.',
      ),
    ],
  ),
];
