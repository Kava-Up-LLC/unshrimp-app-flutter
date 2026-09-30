import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../shared/widgets/error_banner.dart';
import '../../shared/widgets/submit_button.dart';
import '../view_models/change_password_view_model.dart';

class ChangePasswordView extends ConsumerWidget {
  const ChangePasswordView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(changePasswordViewModelProvider);
    final viewModel = ref.read(changePasswordViewModelProvider.notifier);

    ref.listen(changePasswordViewModelProvider, (_, next) {
      if (next.isDone) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Password changed.')));
        context.pop();
      } else if (next.errorCode == 'INVALID_TOKEN') {
        context.go(AppRoutes.logIn);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(
              enabled: !state.isLoading,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Current password',
                errorText: state.oldPasswordError,
              ),
              onChanged: viewModel.oldPasswordChanged,
            ),
            const SizedBox(height: 16),
            TextField(
              enabled: !state.isLoading,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'New password',
                errorText: state.newPasswordError,
              ),
              onChanged: viewModel.newPasswordChanged,
            ),
            const SizedBox(height: 16),
            TextField(
              enabled: !state.isLoading,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Confirm new password',
                errorText: state.confirmPasswordError,
              ),
              onChanged: viewModel.confirmPasswordChanged,
              onSubmitted: (_) => viewModel.submit(),
            ),
            const SizedBox(height: 24),
            if (state.errorMessage case final message?) ...[
              ErrorBanner(message: message),
              const SizedBox(height: 16),
            ],
            SubmitButton(
              label: 'Change password',
              isLoading: state.isLoading,
              onPressed: viewModel.submit,
            ),
          ],
        ),
      ),
    );
  }
}
