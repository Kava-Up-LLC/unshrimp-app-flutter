import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_status.dart';

/// App-bar chip shown while Home is serving cached data offline. When the
/// data's age is known it adds "as of 10:42" beside "Offline"; otherwise just
/// "Offline". Renders nothing when online.
class OfflineIndicator extends ConsumerWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(cacheStatusProvider);
    if (!status.offline) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    final asOf = status.asOf;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              'Offline',
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
            if (asOf != null) ...[
              const SizedBox(width: 4),
              Text(
                'as of ${TimeOfDay.fromDateTime(asOf).format(context)}',
                style: theme.textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
