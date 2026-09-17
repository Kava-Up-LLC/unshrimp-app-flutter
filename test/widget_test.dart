import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:move_well_app/core/config/move_well_app.dart';
import 'package:move_well_app/features/auth/repositories/auth_repository.dart';
import 'package:move_well_app/features/auth/repositories/token_storage.dart';

import 'features/auth/fakes.dart';

void main() {
  testWidgets('App boots into Log In when there is no session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
        ],
        child: const MoveWellApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Don't have an account? Sign Up"), findsOneWidget);
  });

  testWidgets('App boots into Home with a valid session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage('t')),
        ],
        child: const MoveWellApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MoveWell'), findsWidgets);
  });
}
