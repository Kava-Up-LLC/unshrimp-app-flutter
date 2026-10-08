import 'package:flutter_test/flutter_test.dart';
import 'package:move_well_app/features/roast/repositories/fallback_roast_lines.dart';
import 'package:move_well_app/features/roast/repositories/roast_lines_repository.dart';

import '../reminders/fakes.dart';

void main() {
  test('parses the remote array and caches it', () async {
    final prefs = FakeReminderPreferences();
    final repo = RoastLinesRepository(
      prefs,
      readConfig: (_) async => '["a","b","c"]',
    );

    expect(await repo.loadLines(), ['a', 'b', 'c']);
    expect(prefs.roastLines, '["a","b","c"]'); // cached on success
  });

  test('falls back to the cached array when Remote Config is unavailable', () async {
    final prefs = FakeReminderPreferences(roastLines: '["x","y"]');
    final repo = RoastLinesRepository(
      prefs,
      readConfig: (_) async => throw Exception('offline'),
    );

    expect(await repo.loadLines(), ['x', 'y']);
  });

  test('falls back to the bundled lines when remote and cache are empty', () async {
    final prefs = FakeReminderPreferences();
    final repo = RoastLinesRepository(prefs, readConfig: (_) async => null);

    expect(await repo.loadLines(), fallbackRoastLines);
  });
}
