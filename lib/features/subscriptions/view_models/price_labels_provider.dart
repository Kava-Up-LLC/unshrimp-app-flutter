import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/price_labels.dart';

/// Remote Config key holding the temporary plan prices.
const proPriceLabelsConfigKey = 'pro_price_labels';

/// The plan prices shown on the Pro screen, from Remote Config, falling back to
/// [PriceLabels.fallback] when the key is absent or unreadable.
final priceLabelsProvider = FutureProvider<PriceLabels>((ref) async {
  try {
    return PriceLabels.fromConfigJson(
      await AppAmbitSdk.getString(proPriceLabelsConfigKey),
    );
  } catch (_) {
    return PriceLabels.fallback;
  }
});
