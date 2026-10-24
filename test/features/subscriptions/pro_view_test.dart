import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/subscriptions/models/entitlement.dart';
import 'package:unshrimp_app/features/subscriptions/models/store_product.dart';
import 'package:unshrimp_app/features/subscriptions/services/play_store.dart';
import 'package:unshrimp_app/features/subscriptions/view_models/entitlement_view_model.dart';
import 'package:unshrimp_app/features/subscriptions/view_models/pro_products_provider.dart';
import 'package:unshrimp_app/features/subscriptions/views/pro_view.dart';

import 'fakes.dart';

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
  Future<void> pumpProView(WidgetTester tester, {required bool enabled}) async {
    final store = FakeStore(
      available: true,
      products: const [
        StoreProduct(id: 'unshrimp_pro_monthly', price: r'$1.99/mo'),
        StoreProduct(id: 'unshrimp_pro_yearly', price: r'$14.99/yr'),
      ],
    );
    addTearDown(store.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          purchasesEnabledProvider.overrideWith((ref) async => enabled),
          proProductIdsProvider.overrideWith((ref) async => fallbackProductIds),
          storeProvider.overrideWithValue(store),
          entitlementViewModelProvider.overrideWith(_TrialEntitlementViewModel.new),
        ],
        child: const MaterialApp(home: ProView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('enabled: plan cards with store prices, Subscribe and Restore show',
      (tester) async {
    await pumpProView(tester, enabled: true);

    expect(find.text(r'$1.99/mo'), findsOneWidget);
    expect(find.text(r'$14.99/yr'), findsOneWidget);
    expect(find.text('Subscribe'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
  });

  testWidgets('disabled: no plans, no Subscribe, no Restore', (tester) async {
    await pumpProView(tester, enabled: false);

    expect(find.text('Subscribe'), findsNothing);
    expect(find.text('Restore purchases'), findsNothing);
    expect(find.text(r'$14.99/yr'), findsNothing);
    expect(find.text('Terms'), findsNothing);
    expect(find.text('Privacy'), findsNothing);
    // The screen still renders its benefits.
    expect(find.text('Unshrimp Pro'), findsOneWidget);
  });
}
