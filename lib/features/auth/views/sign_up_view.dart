import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../view_models/sign_up_view_model.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_submit_button.dart';

class SignUpView extends ConsumerWidget {
  const SignUpView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(signUpViewModelProvider);
    final viewModel = ref.read(signUpViewModelProvider.notifier);

    ref.listen(signUpViewModelProvider.select((s) => s.isAuthenticated), (
      _,
      isAuthenticated,
    ) {
      if (isAuthenticated) context.go(AppRoutes.home);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(
              enabled: !state.isLoading,
              autofillHints: const [AutofillHints.name],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Name',
                errorText: state.nameError,
              ),
              onChanged: viewModel.nameChanged,
            ),
            const SizedBox(height: 16),
            TextField(
              enabled: !state.isLoading,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Email',
                errorText: state.emailError,
              ),
              onChanged: viewModel.emailChanged,
            ),
            const SizedBox(height: 16),
            TextField(
              enabled: !state.isLoading,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Password',
                errorText: state.passwordError,
              ),
              onChanged: viewModel.passwordChanged,
            ),
            const SizedBox(height: 16),
            TextField(
              enabled: !state.isLoading,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Confirm password',
                errorText: state.confirmPasswordError,
              ),
              onChanged: viewModel.confirmPasswordChanged,
              onSubmitted: (_) => viewModel.submit(),
            ),
            const SizedBox(height: 24),
            if (state.errorMessage case final message?) ...[
              AuthErrorBanner(message: message),
              const SizedBox(height: 16),
            ],
            AuthSubmitButton(
              label: 'Create account',
              isLoading: state.isLoading,
              onPressed: viewModel.submit,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: state.isLoading
                  ? null
                  : () => context.go(AppRoutes.logIn),
              child: const Text('Already have an account? Log In'),
            ),
          ],
        ),
      ),
    );
  }
}
