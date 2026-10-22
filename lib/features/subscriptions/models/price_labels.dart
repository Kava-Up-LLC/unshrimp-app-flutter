import 'dart:convert';

import 'plan_type.dart';

/// The temporary plan prices, from the Remote Config key `pro_price_labels`,
/// shown on the Pro screen until the store is connected and supplies real ones.
class PriceLabels {
  const PriceLabels({required this.monthly, required this.yearly});

  final String monthly;
  final String yearly;

  /// Used when Remote Config has no usable value.
  static const fallback = PriceLabels(
    monthly: r'$1.99 / month',
    yearly: r'$14.99 / year',
  );

  /// Parses the `pro_price_labels` JSON string (`{"monthly": ..., "yearly":
  /// ...}`); a missing or malformed value falls back to [fallback].
  factory PriceLabels.fromConfigJson(String? raw) {
    try {
      final decoded = jsonDecode(raw ?? '');
      if (decoded is Map) {
        return PriceLabels(
          monthly: decoded['monthly']?.toString() ?? fallback.monthly,
          yearly: decoded['yearly']?.toString() ?? fallback.yearly,
        );
      }
    } catch (_) {
      // Not valid JSON: use the fallback.
    }
    return fallback;
  }

  String labelFor(PlanType plan) =>
      plan == PlanType.monthly ? monthly : yearly;
}
