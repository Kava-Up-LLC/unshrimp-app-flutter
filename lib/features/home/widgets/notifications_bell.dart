import 'package:flutter/material.dart';

/// The app bar's bell, with a coral dot on its top-right corner while there
/// are unread notifications. The dot sits inside the icon's box, so the bell
/// never moves.
class NotificationsBell extends StatelessWidget {
  const NotificationsBell({
    super.key,
    required this.hasUnread,
    required this.onPressed,
  });

  static const dotKey = ValueKey('notifications-unread-dot');

  final bool hasUnread;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return IconButton(
      tooltip: hasUnread ? 'Notifications, unread' : 'Notifications',
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined),
          if (hasUnread)
            Positioned(
              top: 1,
              right: 2,
              child: Container(
                key: dotKey,
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: colors.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surface, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
