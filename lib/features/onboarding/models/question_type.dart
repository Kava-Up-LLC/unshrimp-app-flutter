/// How an onboarding question is answered.
enum QuestionType {
  /// Pick one of the question's options.
  singleChoice,

  /// Pick a start and an end time.
  timeRange;

  /// Parses the CMS `type` value (`single_choice` / `time_range`).
  static QuestionType fromCms(Object? value) =>
      value == 'time_range' ? timeRange : singleChoice;
}
