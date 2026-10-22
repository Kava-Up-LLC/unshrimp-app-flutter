import 'package:flutter/material.dart';

import '../models/pro_benefits.dart';
import 'pro_benefit_row.dart';

/// Shows the "Welcome to Unshrimp Pro" modal after a successful purchase.
/// Completes when the user taps "Let's go"; the caller then refreshes the
/// entitlement and returns the user to where they were.
Future<void> showWelcomeProModal(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => const _WelcomeProModal(),
);

class _WelcomeProModal extends StatelessWidget {
  const _WelcomeProModal();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.verified, color: colors.primary, size: 48),
            const SizedBox(height: 16),
            Text(
              'Welcome to Unshrimp Pro',
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            for (final benefit in proBenefits) ProBenefitRow(label: benefit),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Let's go"),
            ),
          ],
        ),
      ),
    );
  }
}
