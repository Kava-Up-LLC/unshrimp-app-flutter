import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/subscriptions/models/plan_type.dart';
import 'package:unshrimp_app/features/subscriptions/models/store_product.dart';
import 'package:unshrimp_app/features/subscriptions/services/play_store.dart';
import 'package:unshrimp_app/features/subscriptions/view_models/pro_products_provider.dart';

import 'fakes.dart';

void main() {
  group('parsePurchasesEnabled', () {
    test('only an explicit true/1 enables purchases', () {
      expect(parsePurchasesEnabled('true'), isTrue);
      expect(parsePurchasesEnabled('1'), isTrue);
      expect(parsePurchasesEnabled('TRUE'), isTrue);
      for (final off in [null, '', 'false', '0', 'yes', 'nonsense']) {
        expect(parsePurchasesEnabled(off), isFalse, reason: 'for "$off"');
      }
    });
  });

  group('parseProductIds', () {
    test('parses the JSON map', () {
      final ids = parseProductIds('{"monthly":"m.id","yearly":"y.id"}');
      expect(ids[PlanType.monthly], 'm.id');
      expect(ids[PlanType.yearly], 'y.id');
    });

    test('falls back when missing or malformed', () {
      for (final raw in [null, '', 'not json', '{}', '{"monthly":"m"}']) {
        expect(parseProductIds(raw), fallbackProductIds, reason: 'for "$raw"');
      }
    });
  });

  group('proPlansProvider', () {
    Future<Map<PlanType, StoreProduct>> plansWith({
      required bool enabled,
      required FakeStore store,
    }) async {
      final container = ProviderContainer(
        overrides: [
          purchasesEnabledProvider.overrideWith((ref) async => enabled),
          proProductIdsProvider.overrideWith((ref) async => fallbackProductIds),
          storeProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      return container.read(proPlansProvider.future);
    }

    test('is empty when purchases are disabled (store untouched)', () async {
      final store = FakeStore(available: true, products: const [
        StoreProduct(id: 'unshrimp_pro_monthly', price: r'$1.99'),
      ]);
      expect(await plansWith(enabled: false, store: store), isEmpty);
    });

    test('is empty when the store returns no matching products', () async {
      final store = FakeStore(available: true, products: const []);
      expect(await plansWith(enabled: true, store: store), isEmpty);
    });

    test('maps the store products the ids resolve to, with store prices', () async {
      final store = FakeStore(available: true, products: const [
        StoreProduct(id: 'unshrimp_pro_monthly', price: r'$1.99/mo'),
        StoreProduct(id: 'unshrimp_pro_yearly', price: r'$14.99/yr'),
      ]);
      final plans = await plansWith(enabled: true, store: store);
      expect(plans[PlanType.monthly]?.price, r'$1.99/mo');
      expect(plans[PlanType.yearly]?.price, r'$14.99/yr');
    });
  });
}
