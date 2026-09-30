/// A short break exercise, as stored in the CMS content type `exercises`.
class Exercise {
  const Exercise({
    required this.zone,
    required this.title,
    required this.steps,
    this.mediaUrl,
    this.assetPath,
  });

  /// Pain zone it targets: the `pain_zone` onboarding answer (`neck`,
  /// `shoulders`, `lower_back`, `wrists` or `none`).
  final String zone;
  final String title;

  /// One line of instructions.
  final String steps;

  /// Image from the CMS `image` field, which the CMS returns as `image_url`.
  final String? mediaUrl;

  /// Bundled copy of the image, shown when [mediaUrl] can't be loaded.
  final String? assetPath;

  /// Builds an exercise from a CMS entry. Accepts the entry with its fields at
  /// the top level or nested under `data`.
  factory Exercise.fromCms(Map<String, dynamic> json) {
    final fields = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;

    return Exercise(
      zone: fields['zone']?.toString() ?? '',
      title: fields['title']?.toString() ?? '',
      steps: fields['steps']?.toString() ?? '',
      mediaUrl: fields['image_url']?.toString(),
    );
  }
}
