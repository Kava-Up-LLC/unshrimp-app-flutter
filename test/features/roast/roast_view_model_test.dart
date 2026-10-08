import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_well_app/core/analytics/event_log.dart';
import 'package:move_well_app/features/roast/repositories/roast_lines_repository.dart';
import 'package:move_well_app/features/roast/view_models/roast_view_model.dart';

import '../reminders/fakes.dart';

RoastLinesRepository _repo(String json) =>
    RoastLinesRepository(FakeReminderPreferences(), readConfig: (_) async => json);

void main() {
  test('picks a line from the array and logs roast_shown', () async {
    final log = FakeEventLog();
    final container = ProviderContainer(
      overrides: [
        roastLinesRepositoryProvider.overrideWithValue(_repo('["a","b","c"]')),
        roastRandomProvider.overrideWithValue(Random(7)),
        eventLogProvider.overrideWithValue(log),
      ],
    );
    addTearDown(container.dispose);
    container.listen(roastViewModelProvider, (_, _) {});

    final line = await container.read(roastViewModelProvider.future);

    expect(['a', 'b', 'c'], contains(line));
    expect(log.events, contains('roast_shown'));
  });

  test('share logs roast_shared and appends " - Unshrimp"', () async {
    final log = FakeEventLog();
    String? shared;
    final container = ProviderContainer(
      overrides: [
        roastLinesRepositoryProvider.overrideWithValue(_repo('["only line"]')),
        eventLogProvider.overrideWithValue(log),
        shareTextProvider.overrideWithValue((text) async => shared = text),
      ],
    );
    addTearDown(container.dispose);
    container.listen(roastViewModelProvider, (_, _) {});
    await container.read(roastViewModelProvider.future);

    await container.read(roastViewModelProvider.notifier).share();

    expect(shared, 'only line - Unshrimp');
    expect(log.events, contains('roast_shared'));
  });
}
