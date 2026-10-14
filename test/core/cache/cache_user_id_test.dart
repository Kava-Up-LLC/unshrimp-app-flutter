import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:move_well_app/core/cache/cache_user_id.dart';

String _token(Map<String, dynamic> payload) {
  String seg(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${seg({'alg': 'HS256'})}.${seg(payload)}.signature';
}

void main() {
  test('reads the sub claim as the cache user id', () {
    expect(cacheUserIdFromToken(_token({'sub': 42, 'exp': 1})), '42');
  });

  test('a malformed token falls back to a stable id, never throws', () {
    expect(cacheUserIdFromToken('not-a-jwt'), 'unknown');
    expect(cacheUserIdFromToken(''), 'unknown');
  });
}
