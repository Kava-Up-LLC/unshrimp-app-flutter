import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../view_models/update_gate_view_model.dart';

/// Blocking wall shown at startup when the running build is below
/// `min_supported_version`. There is no dismiss and no route out: it replaces
/// the app entirely until the user updates. The store button appears only when
/// Remote Config supplies an `update_url`; otherwise the screen tells the user
/// where to go in words.
class UpdateRequiredView extends ConsumerWidget {
  const UpdateRequiredView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final storeUrl = ref.watch(updateStoreUrlProvider).value;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.coralContainerDark,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: Image.asset(
                    'assets/images/shrimp_hurt.png',
                    width: 220,
                    height: 220,
                    cacheWidth: 540,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(width: 180, height: 180),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Time for a fresh Unshrimp',
                  textAlign: TextAlign.center,
                  // White passes AA on coralContainerDark (#7A2A18, ~9.67:1).
                  style: textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This version has slouched into retirement. Update to the '
                  'latest Unshrimp to keep your spine (and the app) working.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(color: Colors.white),
                ),
                const Spacer(),
                if (storeUrl != null)
                  FilledButton(
                    onPressed: () => openStoreListing(storeUrl),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.textLight,
                    ),
                    child: const Text('Update Unshrimp'),
                  )
                else
                  Text(
                    'Open the app store on your device and update Unshrimp to '
                    'continue.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
