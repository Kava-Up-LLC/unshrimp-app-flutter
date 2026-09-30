import 'dart:convert';

/// The Remote Config value `sarcasm_pack`:
/// `{"active": "default", "packs": {"default": [...], "halloween": [...]}}`.
class SarcasmPack {
  const SarcasmPack({required this.active, required this.lines});

  static const defaultPack = 'default';

  /// Name of the pack in use.
  final String active;

  /// Lines of the active pack, or of `default` when the active one is missing.
  final List<String> lines;

  /// Null when [raw] is empty, malformed or has no lines to show.
  static SarcasmPack? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map || json['packs'] is! Map) return null;
      final packs = json['packs'] as Map;
      final active = json['active']?.toString() ?? defaultPack;

      List<String> linesOf(Object? pack) => pack is List
          ? pack
                .map((line) => line.toString().trim())
                .where((line) => line.isNotEmpty)
                .toList()
          : const [];

      final lines = linesOf(packs[active]);
      if (lines.isNotEmpty) return SarcasmPack(active: active, lines: lines);
      final fallback = linesOf(packs[defaultPack]);
      if (fallback.isNotEmpty) {
        return SarcasmPack(active: defaultPack, lines: fallback);
      }
    } on FormatException {
      // Not JSON.
    }
    return null;
  }
}
