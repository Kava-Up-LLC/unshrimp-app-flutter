import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../models/entitlement.dart';
import '../view_models/entitlement_view_model.dart';
import '../view_models/trial_config_provider.dart';

/// The status pill under the Home greeting. Teal for a healthy trial or paid
/// Pro, amber when the trial is almost over, neutral for Free. Tapping it opens
/// the Pro screen.
class ProStatusPill extends ConsumerWidget {
  const ProStatusPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(entitlementViewModelProvider).value;
    if (entitlement == null) return const SizedBox.shrink();

    final warningDays =
        ref.watch(trialWarningDaysProvider).value ?? defaultTrialWarningDays;
    final colors = Theme.of(context).colorScheme;
    final (label, background, foreground) = _pill(
      entitlement,
      warningDays,
      colors,
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => context.push(AppRoutes.pro),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  (String, Color, Color) _pill(
    Entitlement entitlement,
    int warningDays,
    ColorScheme colors,
  ) {
    if (entitlement.isPaid) {
      return ('Pro', colors.primaryContainer, colors.onPrimaryContainer);
    }
    if (entitlement.isTrial) {
      final days = entitlement.trialDaysLeft(DateTime.now());
      final dayWord = days == 1 ? 'day' : 'days';
      if (days <= warningDays) {
        return (
          'Trial ends in $days $dayWord',
          colors.tertiaryContainer,
          colors.onTertiaryContainer,
        );
      }
      return (
        'Pro trial · $days $dayWord left',
        colors.primaryContainer,
        colors.onPrimaryContainer,
      );
    }
    return (
      'Free plan · See Pro',
      colors.surfaceContainerHighest,
      colors.onSurfaceVariant,
    );
  }
}
