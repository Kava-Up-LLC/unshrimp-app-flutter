import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/entitlement.dart';
import '../models/plan_type.dart';
import '../models/pro_benefits.dart';
import '../models/purchase_result.dart';
import '../models/store_product.dart';
import '../view_models/entitlement_view_model.dart';
import '../view_models/pro_products_provider.dart';
import '../view_models/purchase_view_model.dart';
import '../view_models/selected_plan_provider.dart';
import '../widgets/pro_benefit_row.dart';
import '../widgets/pro_plan_card.dart';
import '../widgets/welcome_pro_modal.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

/// The Pro screen: the trial line, what Pro unlocks, what stays free, and — when
/// purchases are enabled and the store returns the plans — the plan cards with
/// the store's localized prices, Subscribe and Restore. With `purchases_enabled`
/// off (the production default), none of the store UI shows.
class ProView extends ConsumerWidget {
  const ProView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final entitlement = ref.watch(entitlementViewModelProvider).value;
    final plans = ref.watch(proPlansProvider).value ?? const <PlanType, StoreProduct>{};
    final selected = ref.watch(selectedPlanProvider);
    final isBuying = ref.watch(purchaseViewModelProvider);
    final showStore = plans.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Unshrimp Pro')),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: isBuying,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (entitlement != null)
                Text(
                  _trialLine(entitlement),
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 24),
              for (final benefit in proBenefits) ProBenefitRow(label: benefit),
              const SizedBox(height: 16),
              Text(
                'Free keeps reminders, the Posture Roast, the Spine Battery and '
                'your streak.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (showStore) ...[
                const SizedBox(height: 24),
                if (plans[PlanType.monthly] case final monthly?)
                  ProPlanCard(
                    title: 'Monthly',
                    price: monthly.price,
                    selected: selected == PlanType.monthly,
                    bestValue: false,
                    onTap: () => ref
                        .read(selectedPlanProvider.notifier)
                        .select(PlanType.monthly),
                  ),
                if (plans[PlanType.yearly] case final yearly?) ...[
                  const SizedBox(height: 12),
                  ProPlanCard(
                    title: 'Yearly',
                    price: yearly.price,
                    selected: selected == PlanType.yearly,
                    bestValue: true,
                    onTap: () => ref
                        .read(selectedPlanProvider.notifier)
                        .select(PlanType.yearly),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isBuying ? null : () => _subscribe(context, ref, plans),
                  child: isBuying
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Subscribe'),
                ),
                TextButton(
                  onPressed: () => _restore(context, ref),
                  child: const Text('Restore purchases'),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _comingSoon(context, 'Terms'),
                    child: const Text('Terms'),
                  ),
                  Text('·', style: TextStyle(color: colors.onSurfaceVariant)),
                  TextButton(
                    onPressed: () => _comingSoon(context, 'Privacy'),
                    child: const Text('Privacy'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _trialLine(Entitlement entitlement) {
    if (entitlement.isPaid) return "You're on Unshrimp Pro";
    final ends = entitlement.trialEndsAt;
    if (entitlement.isTrial && ends != null) {
      return 'Your trial ends ${_formatDate(ends)}';
    }
    return 'Your trial ended';
  }

  Future<void> _subscribe(
    BuildContext context,
    WidgetRef ref,
    Map<PlanType, StoreProduct> plans,
  ) async {
    final selected = ref.read(selectedPlanProvider);
    // The selected plan may not be on sale (only one card showing); fall back.
    final product = plans[selected] ?? plans.values.first;
    final result = await ref.read(purchaseViewModelProvider.notifier).buy(product);
    if (!context.mounted) return;
    switch (result) {
      case PurchaseResult.purchased:
        // The cloud grant already refreshed the entitlement (pill and locks).
        await showWelcomeProModal(context);
      case PurchaseResult.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('That purchase did not go through. Please try again.'),
          ),
        );
      case PurchaseResult.cancelled:
        break;
    }
  }

  void _restore(BuildContext context, WidgetRef ref) {
    ref.read(purchaseViewModelProvider.notifier).restore();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checking your purchases…')),
    );
  }

  void _comingSoon(BuildContext context, String what) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$what opens soon.')),
      );
}
