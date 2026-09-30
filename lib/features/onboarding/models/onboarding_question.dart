import 'question_option.dart';
import 'question_type.dart';

/// A question of the onboarding flow, as stored in the CMS content type
/// `onboarding_questions`.
class OnboardingQuestion {
  const OnboardingQuestion({
    required this.key,
    required this.order,
    required this.title,
    required this.subtitle,
    required this.type,
    this.options = const [],
    this.defaultStart,
    this.defaultEnd,
  });

  /// Answer key sent to `save_onboarding` (e.g. `sitting_hours`).
  final String key;
  final int order;
  final String title;
  final String subtitle;
  final QuestionType type;

  /// Choices of a [QuestionType.singleChoice] question.
  final List<QuestionOption> options;

  /// Preselected `HH:mm` times of a [QuestionType.timeRange] question.
  final String? defaultStart;
  final String? defaultEnd;

  /// Builds a question from a CMS entry. Accepts the entry with its fields at
  /// the top level or nested under `data`.
  factory OnboardingQuestion.fromCms(Map<String, dynamic> json) {
    final fields = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final options = fields['options'] as List? ?? const [];
    final defaults = fields['defaults'] as Map? ?? const {};

    return OnboardingQuestion(
      key: fields['key']?.toString() ?? '',
      order: (fields['order'] as num?)?.toInt() ?? 0,
      title: fields['title']?.toString() ?? '',
      subtitle: fields['subtitle']?.toString() ?? '',
      type: QuestionType.fromCms(fields['type']),
      options: [
        for (final option in options)
          QuestionOption.fromJson(Map<String, dynamic>.from(option as Map)),
      ],
      defaultStart: defaults['start']?.toString(),
      defaultEnd: defaults['end']?.toString(),
    );
  }
}
