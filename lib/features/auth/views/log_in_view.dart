import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../view_models/log_in_view_model.dart';
import '../../shared/widgets/error_banner.dart';
import '../../shared/widgets/submit_button.dart';

class LogInView extends ConsumerWidget {
  const LogInView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(logInViewModelProvider);
    final viewModel = ref.read(logInViewModelProvider.notifier);

    ref.listen(logInViewModelProvider.select((s) => s.isAuthenticated), (
      _,
      isAuthenticated,
    ) {
      if (isAuthenticated) context.go(AppRoutes.home);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Log In')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: ClipOval(
                child: Image.asset(
                  'assets/images/icon_round.png',
                  width: 128,
                  height: 128,
                  // Decode near the painted size (128 logical px up to 3x).
                  cacheWidth: 384,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              enabled: !state.isLoading,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Email'),
              onChanged: viewModel.emailChanged,
            ),
            const SizedBox(height: 16),
            TextField(
              enabled: !state.isLoading,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'Password'),
              onChanged: viewModel.passwordChanged,
              onSubmitted: (_) => viewModel.submit(),
            ),
            const SizedBox(height: 24),
            if (state.errorMessage case final message?) ...[
              ErrorBanner(message: message),
              const SizedBox(height: 16),
            ],
            SubmitButton(
              label: 'Log In',
              isLoading: state.isLoading,
              onPressed: viewModel.submit,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: state.isLoading
                  ? null
                  : () => context.go(AppRoutes.signUp),
              child: const Text("Don't have an account? Sign Up"),
            ),
          ],
        ),
      ),
    );
  }
}
