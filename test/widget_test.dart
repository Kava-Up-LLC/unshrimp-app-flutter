import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:move_well_app/core/config/move_well_app.dart';
import 'package:move_well_app/features/auth/repositories/auth_repository.dart';
import 'package:move_well_app/features/auth/repositories/token_storage.dart';
import 'package:move_well_app/features/home/repositories/home_repository.dart';

import 'features/auth/fakes.dart';
import 'features/home/fakes.dart';

void main() {
  testWidgets('App boots into Log In when there is no session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
        ],
        child: const MoveWellApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Don't have an account? Sign Up"), findsOneWidget);
  });

  testWidgets('App boots into Home and shows the real stats', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage('t')),
        ],
        child: const MoveWellApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hi Grace Hopper'), findsOneWidget);
    expect(find.text('4 days'), findsOneWidget);
    expect(find.text('3/5'), findsOneWidget);
    expect(find.text('2 breaks'), findsOneWidget);
    expect(find.text('Take a break now'), findsOneWidget);
  });
}
