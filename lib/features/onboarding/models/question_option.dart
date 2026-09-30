/// One choice of a single-choice onboarding question.
class QuestionOption {
  const QuestionOption({
    required this.label,
    required this.value,
    this.description,
  });

  /// Text the user sees.
  final String label;

  /// Value stored when the user picks it.
  final String value;

  /// Optional one-line descriptor shown under the label.
  final String? description;

  static const _descriptionSeparator = ' — ';

  /// Reads `description` when the entry has one; otherwise splits a combined
  /// label such as "Gentle — Cheers you on." into label and descriptor.
  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    final label = json['label']?.toString() ?? '';
    final value = json['value']?.toString() ?? '';
    final description = json['description']?.toString();
    if (description != null) {
      return QuestionOption(
        label: label,
        value: value,
        description: description,
      );
    }

    final separator = label.indexOf(_descriptionSeparator);
    if (separator == -1) return QuestionOption(label: label, value: value);
    return QuestionOption(
      label: label.substring(0, separator),
      value: value,
      description: label.substring(separator + _descriptionSeparator.length),
    );
  }
}
