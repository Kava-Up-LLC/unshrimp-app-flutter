import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_well_app/core/cloud/cloud_functions.dart';
import 'package:move_well_app/features/auth/models/auth_exception.dart';

CloudCodeResponse _ok(Map<String, dynamic> data) =>
    CloudCodeResponse(data: data, statusCode: 200, requestId: null, headers: const {});

/// A fake invoke that runs [steps] in order, one per call, and counts calls.
({CloudInvoke invoke, int Function() calls}) _sequence(
  List<Future<CloudCodeResponse> Function()> steps,
) {
  var i = 0;
  Future<CloudCodeResponse> invoke(String fn, Map<String, Object?> body, Duration t) {
    final step = steps[i < steps.length ? i : steps.length - 1];
    i++;
    return step();
  }

  return (invoke: invoke, calls: () => i);
}

CloudFunctions _cloud(CloudInvoke invoke) =>
    CloudFunctions(invoke: invoke, retryDelay: Duration.zero);

void main() {
  test('a read (retry: true) that times out is called twice and succeeds', () async {
    final seq = _sequence([
      () => throw const CloudCodeError(code: CloudCodeErrorCode.timedOut, message: 'slow'),
      () async => _ok({'ok': true}),
    ]);

    final data = await _cloud(seq.invoke).call('fn', {'token': 't'}, retry: true);

    expect(data, {'ok': true});
    expect(seq.calls(), 2);
  });

  test('a mutation (default: no retry) that times out is called once and throws', () async {
    final seq = _sequence([
      () => throw const CloudCodeError(code: CloudCodeErrorCode.timedOut, message: 'slow'),
    ]);

    await expectLater(
      _cloud(seq.invoke).call('fn', {'token': 't'}),
      throwsA(isA<AuthException>().having((e) => e.code, 'code', 'timedOut')),
    );
    expect(seq.calls(), 1); // never retried — a committed mutation must not re-apply
  });

  test('a read (retry: true) also retries an http error', () async {
    final seq = _sequence([
      () => throw const CloudCodeError(code: CloudCodeErrorCode.http, message: 'boom'),
      () async => _ok({'ok': true}),
    ]);

    final data = await _cloud(seq.invoke).call('fn', {}, retry: true);

    expect(data, {'ok': true});
    expect(seq.calls(), 2);
  });

  test('does not retry a function {error} reply (INVALID_TOKEN), even a read', () async {
    final seq = _sequence([
      () async => _ok({'error': 'INVALID_TOKEN', 'message': 'expired'}),
    ]);

    await expectLater(
      _cloud(seq.invoke).call('fn', {}, retry: true),
      throwsA(isA<AuthException>().having((e) => e.code, 'code', 'INVALID_TOKEN')),
    );
    expect(seq.calls(), 1);
  });

  test('does not retry a non-transient CloudCodeError (badArgs), even a read', () async {
    final seq = _sequence([
      () => throw const CloudCodeError(code: CloudCodeErrorCode.badArgs, message: 'bad'),
    ]);

    await expectLater(
      _cloud(seq.invoke).call('fn', {}, retry: true),
      throwsA(isA<AuthException>().having((e) => e.code, 'code', 'badArgs')),
    );
    expect(seq.calls(), 1);
  });

  test('a read gives up after a single retry when the http error persists', () async {
    final seq = _sequence([
      () => throw const CloudCodeError(code: CloudCodeErrorCode.http, message: 'boom'),
      () => throw const CloudCodeError(code: CloudCodeErrorCode.http, message: 'boom'),
    ]);

    await expectLater(
      _cloud(seq.invoke).call('fn', {}, retry: true),
      throwsA(isA<AuthException>().having((e) => e.code, 'code', 'http')),
    );
    expect(seq.calls(), 2);
  });
}
