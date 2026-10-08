import 'package:flutter/material.dart';

import '../models/app_notification.dart';

/// One notification. Unread ones get a tinted background, a teal dot and
/// bold text.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    this.onLongPress,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final unread = !notification.read;
    // The user let this reminder lapse: mark it in the coral side of the
    // palette (the Posture Roast / shrimp colour), read or not.
    final ignored = notification.wasIgnored;
    final title = notification.title.trim();

    return Material(
      color: ignored
          ? colors.secondaryContainer.withValues(alpha: 0.45)
          : unread
          ? colors.primaryContainer.withValues(alpha: 0.45)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Icon(
                  Icons.circle,
                  size: 10,
                  color: ignored
                      ? colors.secondary
                      : unread
                      ? colors.primary
                      : Colors.transparent,
                  semanticLabel: ignored
                      ? 'Ignored'
                      : unread
                      ? 'Unread'
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty) ...[
                      Text(
                        title,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      notification.body,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: unread && title.isEmpty
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: unread
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _formatTime(notification.sentAt.toLocal()),
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        if (ignored) ...[
                          Text(
                            '  ·  ',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            'Ignored',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// `14:05` today, `Sep 28, 14:05` on other days.
  static String _formatTime(DateTime time) {
    final now = DateTime.now();
    final clock =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final today =
        time.year == now.year && time.month == now.month && time.day == now.day;
    return today ? clock : '${_months[time.month - 1]} ${time.day}, $clock';
  }
}
