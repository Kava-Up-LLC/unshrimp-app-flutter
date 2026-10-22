import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unshrimp_app/features/subscriptions/services/pro_preferences.dart';

import '../../support/in_memory_prefs.dart';

void main() {
  setUp(useInMemoryPrefs);

  test('the one-time flags default false, flip to true, and clear', () async {
    final prefs = ProPreferences(SharedPreferencesAsync());

    expect(await prefs.wasTrialStartedShown(), isFalse);
    expect(await prefs.wasTrialEndedShown(), isFalse);

    await prefs.markTrialStartedShown();
    await prefs.markTrialEndedShown();
    expect(await prefs.wasTrialStartedShown(), isTrue);
    expect(await prefs.wasTrialEndedShown(), isTrue);

    await prefs.clear();
    expect(await prefs.wasTrialStartedShown(), isFalse);
    expect(await prefs.wasTrialEndedShown(), isFalse);
  });
}
