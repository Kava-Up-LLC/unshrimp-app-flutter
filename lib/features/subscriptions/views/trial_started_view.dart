import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../models/pro_benefits.dart';
import '../view_models/entitlement_view_model.dart';
import '../view_models/pro_products_provider.dart';
import '../widgets/pro_benefit_row.dart';

/// Shown once, right after onboarding: the trial has started. "Start my trial"
/// and the close X go to Home; "Subscribe now" opens the Pro screen.
class TrialStartedView extends ConsumerWidget {
  const TrialStartedView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final entitlement = ref.watch(entitlementViewModelProvider).value;
    final days = entitlement?.trialDaysLeft(DateTime.now()) ?? 14;
    final trialDays = days > 0 ? days : 14;
    final purchasesEnabled = ref.watch(purchasesEnabledProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: () => context.go(AppRoutes.home),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Icon(Icons.workspace_premium, color: colors.primary, size: 56),
              const SizedBox(height: 20),
              Text(
                'Your $trialDays-day Pro trial has started',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              for (final benefit in proBenefits) ProBenefitRow(label: benefit),
              const Spacer(),
              Text(
                'No card needed. After $trialDays days you keep the basics for '
                'free.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Start my trial'),
              ),
              if (purchasesEnabled) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.push(AppRoutes.pro),
                  child: const Text('Subscribe now'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
