import 'package:flutter/material.dart';

/// Asks the user to confirm logging out. Returns true only on "Log out".
Future<bool> confirmLogOut(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text('Reminders stop until you log in again.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
