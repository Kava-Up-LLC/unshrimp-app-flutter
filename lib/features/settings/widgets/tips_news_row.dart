import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../push/view_models/tips_enabled_view_model.dart';
import 'settings_row.dart';

/// The "Tips and news" push toggle under Notifications. Default on, and fully
/// independent of the reminder switches — it only drives the SDK push flag.
class TipsNewsRow extends ConsumerWidget {
  const TipsNewsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tips = ref.watch(tipsEnabledViewModelProvider);
    final enabled = tips.value ?? true; // Default on, incl. while loading.
    final busy = tips.isLoading;
    final notifier = ref.read(tipsEnabledViewModelProvider.notifier);
    return SettingsRow(
      label: 'Tips and news',
      subtitle: 'Occasional posture tips and product news.',
      trailing: Switch(
        value: enabled,
        onChanged: busy ? null : notifier.set,
      ),
      onTap: busy ? null : () => notifier.set(!enabled),
    );
  }
}
