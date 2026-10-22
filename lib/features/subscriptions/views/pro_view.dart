import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/entitlement.dart';
import '../models/plan_type.dart';
import '../models/price_labels.dart';
import '../models/pro_benefits.dart';
import '../view_models/entitlement_view_model.dart';
import '../view_models/price_labels_provider.dart';
import '../view_models/selected_plan_provider.dart';
import '../widgets/pro_benefit_row.dart';
import '../widgets/pro_plan_card.dart';
import '../widgets/welcome_pro_modal.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

/// The Pro screen: the trial line, what Pro unlocks, what stays free, the two
/// plans, and Subscribe. The store isn't wired yet, so Subscribe just shows the
/// confirmation modal; the trial keeps everything unlocked meanwhile.
class ProView extends ConsumerWidget {
  const ProView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final entitlement = ref.watch(entitlementViewModelProvider).value;
    final labels =
        ref.watch(priceLabelsProvider).value ?? PriceLabels.fallback;
    final selected = ref.watch(selectedPlanProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Unshrimp Pro')),
      body: SafeArea(
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
            const SizedBox(height: 24),
            ProPlanCard(
              title: 'Monthly',
              price: labels.labelFor(PlanType.monthly),
              selected: selected == PlanType.monthly,
              bestValue: false,
              onTap: () => ref
                  .read(selectedPlanProvider.notifier)
                  .select(PlanType.monthly),
            ),
            const SizedBox(height: 12),
            ProPlanCard(
              title: 'Yearly',
              price: labels.labelFor(PlanType.yearly),
              selected: selected == PlanType.yearly,
              bestValue: true,
              onTap: () => ref
                  .read(selectedPlanProvider.notifier)
                  .select(PlanType.yearly),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => showWelcomeProModal(context),
              child: const Text('Subscribe'),
            ),
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

  void _comingSoon(BuildContext context, String what) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$what opens soon.')),
      );
}
