import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../models/entitlement.dart';
import '../models/pro_benefits.dart';
import '../services/pro_preferences.dart';
import '../view_models/entitlement_view_model.dart';

/// What the user keeps for free after the trial.
const _staysFree = [
  'Reminders',
  'The Posture Roast',
  'The Spine Battery',
  'Your streak',
];

/// Invisible host that shows the "Your Pro trial ended" sheet once, the first
/// time Home is built with a lapsed trial. Marks it shown before displaying, so
/// it never reappears. Not a wall — the sheet is dismissible.
class TrialEndedSheetHost extends ConsumerStatefulWidget {
  const TrialEndedSheetHost({super.key});

  @override
  ConsumerState<TrialEndedSheetHost> createState() =>
      _TrialEndedSheetHostState();
}

class _TrialEndedSheetHostState extends ConsumerState<TrialEndedSheetHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    final Entitlement entitlement;
    try {
      entitlement = await ref.read(entitlementViewModelProvider.future);
    } catch (_) {
      return; // No entitlement (e.g. rejected token): nothing to show.
    }
    if (!mounted || !_isLapsedTrial(entitlement)) return;

    final prefs = ref.read(proPreferencesProvider);
    if (await prefs.wasTrialEndedShown()) return;
    await prefs.markTrialEndedShown();
    if (!mounted) return;
    await _showSheet(context);
  }

  /// Free now, but there was a trial and it is in the past.
  bool _isLapsedTrial(Entitlement e) {
    final ends = e.trialEndsAt;
    return !e.isPro && ends != null && ends.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<void> _showSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheetContext) {
    final textTheme = Theme.of(sheetContext).textTheme;
    final colors = Theme.of(sheetContext).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your Pro trial ended',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'What stays free',
              style: textTheme.titleSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            for (final item in _staysFree)
              _Line(icon: Icons.check, color: colors.primary, text: item),
            const SizedBox(height: 12),
            Text(
              'Now Pro',
              style: textTheme.titleSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            for (final item in proBenefits)
              _Line(icon: Icons.lock_outline, color: colors.secondary, text: item),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                context.push(AppRoutes.pro);
              },
              child: const Text('See Pro'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: const Text('Continue free'),
            ),
          ],
        ),
      ),
    );
  },
);

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    ),
  );
}
