import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unshrimp_app/features/subscriptions/models/entitlement.dart';
import 'package:unshrimp_app/features/subscriptions/services/pro_preferences.dart';
import 'package:unshrimp_app/features/subscriptions/view_models/entitlement_view_model.dart';
import 'package:unshrimp_app/features/subscriptions/widgets/trial_ended_sheet.dart';

import '../../support/in_memory_prefs.dart';

/// A lapsed trial: free now, with a trial that ended yesterday.
class _LapsedEntitlementViewModel extends EntitlementViewModel {
  @override
  Future<Entitlement> build() async => Entitlement(
    isPro: false,
    entitlement: 'free',
    trialEndsAt: DateTime.now().subtract(const Duration(days: 1)),
  );
}

Widget _host(ProPreferences prefs) => ProviderScope(
  overrides: [
    entitlementViewModelProvider.overrideWith(_LapsedEntitlementViewModel.new),
    proPreferencesProvider.overrideWithValue(prefs),
  ],
  child: const MaterialApp(home: Scaffold(body: TrialEndedSheetHost())),
);

void main() {
  setUp(useInMemoryPrefs);

  testWidgets('shows the ended sheet once, then marks it shown', (tester) async {
    final prefs = ProPreferences(SharedPreferencesAsync());
    await tester.pumpWidget(_host(prefs));
    await tester.pumpAndSettle();

    expect(find.text('Your Pro trial ended'), findsOneWidget);
    expect(await prefs.wasTrialEndedShown(), isTrue);

    await tester.tap(find.text('Continue free'));
    await tester.pumpAndSettle();
    expect(find.text('Your Pro trial ended'), findsNothing);
  });

  testWidgets('does not show again once it has been shown', (tester) async {
    final prefs = ProPreferences(SharedPreferencesAsync());
    await prefs.markTrialEndedShown();

    await tester.pumpWidget(_host(prefs));
    await tester.pumpAndSettle();

    expect(find.text('Your Pro trial ended'), findsNothing);
  });
}
