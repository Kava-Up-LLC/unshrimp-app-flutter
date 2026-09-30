import 'package:flutter/material.dart';

/// Shows a 24-hour time picker starting at [current] (`HH:mm`, or 09:00 when
/// missing). Returns null when dismissed.
Future<TimeOfDay?> pickTime(BuildContext context, String? current) {
  final parts = (current ?? '').split(':');
  return showTimePicker(
    context: context,
    initialTime: TimeOfDay(
      hour: int.tryParse(parts.first) ?? 9,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
}
