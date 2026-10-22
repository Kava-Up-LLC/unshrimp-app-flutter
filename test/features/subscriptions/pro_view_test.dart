import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/subscriptions/models/entitlement.dart';
import 'package:unshrimp_app/features/subscriptions/models/price_labels.dart';
import 'package:unshrimp_app/features/subscriptions/view_models/entitlement_view_model.dart';
import 'package:unshrimp_app/features/subscriptions/view_models/price_labels_provider.dart';
import 'package:unshrimp_app/features/subscriptions/view_models/trial_config_provider.dart';
import 'package:unshrimp_app/features/subscriptions/views/pro_view.dart';

/// A trialing entitlement, so the Pro screen builds without touching storage.
class _TrialEntitlementViewModel extends EntitlementViewModel {
  @override
  Future<Entitlement> build() async => Entitlement(
    isPro: true,
    entitlement: 'pro_trial',
    trialEndsAt: DateTime.now().add(const Duration(days: 14)),
  );
}

void main() {
  Future<void> pumpProView(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          priceLabelsProvider.overrideWith((ref) async => PriceLabels.fallback),
          trialWarningDaysProvider.overrideWith((ref) async => 2),
          entitlementViewModelProvider.overrideWith(
            _TrialEntitlementViewModel.new,
          ),
        ],
        child: const MaterialApp(home: ProView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Subscribe shows the confirmation modal', (tester) async {
    await pumpProView(tester);

    await tester.tap(find.text('Subscribe'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Unshrimp Pro'), findsOneWidget);
  });

  testWidgets("the confirmation modal closes on \"Let's go\"", (tester) async {
    await pumpProView(tester);

    await tester.tap(find.text('Subscribe'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Unshrimp Pro'), findsOneWidget);

    await tester.tap(find.text("Let's go"));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Unshrimp Pro'), findsNothing);
  });
}
