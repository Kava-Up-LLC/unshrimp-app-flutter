import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';

import '../../features/auth/models/auth_exception.dart';

/// Performs one Cloud Code invocation. Injectable so the retry logic can be
/// unit-tested without the platform channel.
typedef CloudInvoke =
    Future<CloudCodeResponse> Function(
      String function,
      Map<String, Object?> body,
      Duration timeout,
    );

/// Pulls a function-level error out of a reply body (a success body, or a
/// `CloudCodeError`'s body), or null when there is none.
typedef CloudErrorFrom = AuthException? Function(Map<String, dynamic> data);

/// The single Cloud Code call path for every repository.
///
/// Maps transport failures to [AuthException]. The server's functions can
/// exceed their 10 s timeout on a cold start, so a call may **retry exactly
/// once after 1 s on a transient `http` / `timedOut` error** — but ONLY when
/// the caller opts in with `retry: true`, which is reserved for **idempotent
/// reads**. Mutations (register_ignore/register_break/mark_ignored/update_*/…)
/// must never retry: a timed-out request may already have committed server
/// side, so a retry would double-apply it. Function-level errors (INVALID_TOKEN,
/// NO_SETTINGS, …) come back as a normal `{error}` reply and are never retried;
/// neither are non-transient `CloudCodeError` codes.
class CloudFunctions {
  const CloudFunctions({
    CloudInvoke? invoke,
    Duration retryDelay = const Duration(seconds: 1),
  }) : _invoke = invoke,
       _retryDelay = retryDelay;

  final CloudInvoke? _invoke;
  final Duration _retryDelay;

  static const _timeout = Duration(seconds: 20);

  /// [retry] opts into the single transient retry; pass it true ONLY for
  /// idempotent reads (get_user_stats, get_settings, get_pending_reminders,
  /// auth_validate). It defaults to false, so every mutation is called once.
  Future<Map<String, dynamic>> call(
    String function,
    Map<String, Object?> body, {
    CloudErrorFrom? errorFrom,
    bool retry = false,
  }) async {
    final extract = errorFrom ?? _defaultError;
    // Only callers that opt into a custom extractor (auth) also want errors
    // read out of a CloudCodeError body; the rest keep the generic message.
    final bodyExtract = errorFrom;
    try {
      return _parse(await _invokeOnce(function, body), extract);
    } on CloudCodeError catch (e) {
      if (!retry || !_retriable(e.code)) throw _mapError(e, bodyExtract);
      await Future<void>.delayed(_retryDelay);
      try {
        return _parse(await _invokeOnce(function, body), extract);
      } on CloudCodeError catch (e2) {
        throw _mapError(e2, bodyExtract);
      }
    }
  }

  Future<CloudCodeResponse> _invokeOnce(
    String function,
    Map<String, Object?> body,
  ) => (_invoke ?? _defaultInvoke)(function, body, _timeout);

  static Future<CloudCodeResponse> _defaultInvoke(
    String function,
    Map<String, Object?> body,
    Duration timeout,
  ) => CloudCode.call(function, body: body, timeout: timeout).future;

  // Only a cold-start/server timeout or 5xx is worth a second try. Everything
  // else (bad args, no network, decoding, …) fails fast.
  static bool _retriable(CloudCodeErrorCode code) =>
      code == CloudCodeErrorCode.http || code == CloudCodeErrorCode.timedOut;

  Map<String, dynamic> _parse(CloudCodeResponse response, CloudErrorFrom extract) {
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const AuthException(
        code: 'UNEXPECTED_RESPONSE',
        message: 'Unexpected response from the server.',
      );
    }
    final error = extract(data);
    if (error != null) throw error;
    return data;
  }

  AuthException _mapError(CloudCodeError e, CloudErrorFrom? bodyExtract) {
    final body = e.body;
    final fromBody = (bodyExtract != null && body is Map<String, dynamic>)
        ? bodyExtract(body)
        : null;
    return fromBody ??
        AuthException(
          code: e.code.name,
          message: e.code == CloudCodeErrorCode.http
              ? 'Something went wrong. Please try again.'
              : "Couldn't reach the server. Check your connection and try again.",
        );
  }

  static AuthException? _defaultError(Map<String, dynamic> data) {
    final code = data['error'];
    if (code == null) return null;
    return AuthException(
      code: code.toString(),
      message: (data['message'] ?? code).toString(),
    );
  }
}
