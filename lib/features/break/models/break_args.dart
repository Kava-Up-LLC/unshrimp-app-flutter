import '../../../core/router/app_routes.dart';
import '../../reminders/models/reminder_payload.dart';
import 'break_source.dart';

/// Parameters of a break, carried in its route:
/// `/break?source=reminder&zone=neck`.
class BreakArgs {
  const BreakArgs({required this.source, this.zone, this.reminderKey});

  /// From a tapped reminder's [ReminderPayload]: its zone (none for the debug
  /// reminder) and the key of its `notifications` row.
  factory BreakArgs.fromReminderPayload(String? payload) {
    final decoded = ReminderPayload.decode(payload);
    return BreakArgs(
      source: BreakSource.reminder,
      zone: decoded.zone,
      reminderKey: decoded.key,
    );
  }

  factory BreakArgs.fromUri(Uri uri) {
    final zone = uri.queryParameters['zone'];
    final key = uri.queryParameters['key'];
    return BreakArgs(
      source: BreakSource.values.firstWhere(
        (source) => source.name == uri.queryParameters['source'],
        orElse: () => BreakSource.home,
      ),
      zone: zone == null || zone.isEmpty ? null : zone,
      reminderKey: key == null || key.isEmpty ? null : key,
    );
  }

  final BreakSource source;

  /// Pain zone to stretch; null reads it from the user's settings.
  final String? zone;

  /// The tapped reminder's key, so opening the break marks its row read.
  final String? reminderKey;

  String get location => Uri(
    path: AppRoutes.breakTime,
    queryParameters: {
      'source': source.name,
      'zone': ?zone,
      'key': ?reminderKey,
    },
  ).toString();

  @override
  bool operator ==(Object other) =>
      other is BreakArgs &&
      other.source == source &&
      other.zone == zone &&
      other.reminderKey == reminderKey;

  @override
  int get hashCode => Object.hash(source, zone, reminderKey);
}
