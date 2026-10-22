import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/subscriptions/models/plan_type.dart';
import 'package:unshrimp_app/features/subscriptions/models/price_labels.dart';

void main() {
  test('PriceLabels parses the Remote Config JSON', () {
    final labels = PriceLabels.fromConfigJson(
      '{"monthly": "\$2.99 / month", "yearly": "\$19.99 / year"}',
    );
    expect(labels.labelFor(PlanType.monthly), r'$2.99 / month');
    expect(labels.labelFor(PlanType.yearly), r'$19.99 / year');
  });

  test('PriceLabels falls back when the value is missing or malformed', () {
    for (final raw in [null, '', 'not json', '[]']) {
      final labels = PriceLabels.fromConfigJson(raw);
      expect(labels.monthly, PriceLabels.fallback.monthly);
      expect(labels.yearly, PriceLabels.fallback.yearly);
    }
  });
}
