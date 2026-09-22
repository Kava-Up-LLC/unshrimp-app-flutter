import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/session_status.dart';
import '../repositories/auth_repository.dart';
import '../repositories/token_storage.dart';

final sessionGateViewModelProvider =
    AsyncNotifierProvider.autoDispose<SessionGateViewModel, SessionStatus>(
      SessionGateViewModel.new,
    );

/// Reads the stored token and asks `auth_validate` whether it is still valid.
class SessionGateViewModel extends AsyncNotifier<SessionStatus> {
  @override
  Future<SessionStatus> build() async {
    final storage = ref.read(tokenStorageProvider);
    final token = await storage.read();
    if (token == null) return SessionStatus.unauthenticated;

    try {
      final valid = await ref.read(authRepositoryProvider).validate(token);
      if (valid) return SessionStatus.authenticated;
      await storage.delete();
    } on Exception {
      // Network or backend failure: fall back to Log In, keep the token.
    }
    return SessionStatus.unauthenticated;
  }
}
