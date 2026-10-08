import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/analytics/event_log.dart';
import '../repositories/fallback_roast_lines.dart';
import '../repositories/roast_lines_repository.dart';

/// The source of randomness for the roast line. Overridden (seeded) in tests.
final roastRandomProvider = Provider<Random>((ref) => Random());

/// Opens the OS share sheet with [text]. Overridden in tests.
typedef ShareText = Future<void> Function(String text);

final shareTextProvider = Provider<ShareText>(
  (ref) => (text) => SharePlus.instance.share(ShareParams(text: text)),
);

final roastViewModelProvider =
    AsyncNotifierProvider.autoDispose<RoastViewModel, String>(
      RoastViewModel.new,
      // One roast per view; don't re-pick a line by retrying a failed build.
      retry: (_, _) => null,
    );

/// Picks one roast line (random per roast), logs `roast_shown`, and shares it.
class RoastViewModel extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final lines = await ref.read(roastLinesRepositoryProvider).loadLines();
    // loadLines never returns empty, but guard anyway (last resort: line[0]).
    final line = lines.isEmpty
        ? fallbackRoastLines.first
        : lines[ref.read(roastRandomProvider).nextInt(lines.length)];
    ref.read(eventLogProvider).log('roast_shown');
    return line;
  }

  /// Opens the share sheet with the roast line + " - Unshrimp".
  Future<void> share() async {
    final line = state.value;
    if (line == null) return;
    ref.read(eventLogProvider).log('roast_shared');
    await ref.read(shareTextProvider)('$line - Unshrimp');
  }
}
