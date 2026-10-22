import 'dart:convert';

/// What a reminder notification carries for its tap: the pain zone for the
/// break and the key of the scheduled reminder, to find its `notifications`
/// row. Encoded as `{"zone": "neck", "key": "d1759…-0"}`. A reminder that opens
/// a specific screen instead of a break (the weekly Spine Report → History)
/// carries [route].
class ReminderPayload {
  const ReminderPayload({this.zone, this.key, this.route});

  /// Null: the break reads the zone from the settings.
  final String? zone;

  /// Null for reminders scheduled before keys existed.
  final String? key;

  /// A go_router location to open on tap instead of a break. Null for the
  /// posture reminders, which open a break.
  final String? route;

  String encode() => jsonEncode({'zone': ?zone, 'key': ?key, 'route': ?route});

  /// Accepts the JSON form and the older plain-zone payload, which is
  /// replaced at the next reschedule.
  factory ReminderPayload.decode(String? raw) {
    String? nonEmpty(Object? value) =>
        value is String && value.isNotEmpty ? value : null;

    if (raw == null || raw.isEmpty) return const ReminderPayload();
    try {
      final json = jsonDecode(raw);
      if (json is Map) {
        return ReminderPayload(
          zone: nonEmpty(json['zone']),
          key: nonEmpty(json['key']),
          route: nonEmpty(json['route']),
        );
      }
    } on FormatException {
      // Not JSON: the older payload, just the zone.
    }
    return ReminderPayload(zone: raw);
  }
}
