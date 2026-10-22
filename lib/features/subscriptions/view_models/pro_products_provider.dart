import 'dart:convert';

import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/plan_type.dart';
import '../models/store_product.dart';
import '../services/play_store.dart';

/// Remote Config key that turns the whole purchase UI on. Default OFF, so a
/// production build never shows plans, Subscribe or Restore until it is flipped.
const purchasesEnabledConfigKey = 'purchases_enabled';

/// Remote Config key holding the plan → product id map.
const proProductIdsConfigKey = 'pro_product_ids';

/// The product ids shipped if Remote Config has no usable value.
const fallbackProductIds = {
  PlanType.monthly: 'unshrimp_pro_monthly',
  PlanType.yearly: 'unshrimp_pro_yearly',
};

/// Parses the `purchases_enabled` flag. Anything but an explicit true/1 reads as
/// off, so an absent or malformed value keeps purchases hidden.
bool parsePurchasesEnabled(String? raw) {
  final v = raw?.trim().toLowerCase();
  return v == 'true' || v == '1';
}

/// Parses the `pro_product_ids` JSON (`{"monthly": ..., "yearly": ...}`); a
/// missing or malformed value falls back to [fallbackProductIds].
Map<PlanType, String> parseProductIds(String? raw) {
  try {
    final decoded = jsonDecode(raw ?? '');
    if (decoded is Map) {
      final monthly = decoded['monthly']?.toString();
      final yearly = decoded['yearly']?.toString();
      if (monthly != null && monthly.isNotEmpty &&
          yearly != null && yearly.isNotEmpty) {
        return {PlanType.monthly: monthly, PlanType.yearly: yearly};
      }
    }
  } catch (_) {
    // Not valid JSON: use the fallback.
  }
  return fallbackProductIds;
}

/// Whether the purchase UI may show at all, from Remote Config (default off).
final purchasesEnabledProvider = FutureProvider<bool>((ref) async {
  try {
    return parsePurchasesEnabled(
      await AppAmbitSdk.getString(purchasesEnabledConfigKey),
    );
  } catch (_) {
    return false;
  }
});

/// The plan → product id map, from Remote Config (default [fallbackProductIds]).
final proProductIdsProvider = FutureProvider<Map<PlanType, String>>((ref) async {
  try {
    return parseProductIds(await AppAmbitSdk.getString(proProductIdsConfigKey));
  } catch (_) {
    return fallbackProductIds;
  }
});

/// The plans to show on the Pro screen, each with the store's localized price.
///
/// Empty when purchases are disabled, the store is unavailable, or the store
/// knows none of the ids — so the Pro screen shows no plan cards in those cases.
final proPlansProvider = FutureProvider<Map<PlanType, StoreProduct>>((ref) async {
  if (!await ref.watch(purchasesEnabledProvider.future)) return {};

  final store = ref.read(storeProvider);
  if (!await store.isAvailable()) return {};

  final ids = await ref.watch(proProductIdsProvider.future);
  final products = await store.queryProducts(ids.values.toSet());
  final byId = {for (final p in products) p.id: p};

  return {
    for (final entry in ids.entries)
      if (byId[entry.value] != null) entry.key: byId[entry.value]!,
  };
});
