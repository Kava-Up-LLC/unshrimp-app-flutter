import 'dart:convert';

/// The Remote Config value `roast_lines`: a JSON array of strings.
class RoastLines {
  const RoastLines._();

  /// The parsed lines, or null when [raw] is empty, malformed, or has none.
  static List<String>? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! List) return null;
      final lines = json
          .map((line) => line.toString().trim())
          .where((line) => line.isNotEmpty)
          .toList();
      return lines.isEmpty ? null : lines;
    } on FormatException {
      return null;
    }
  }
}
