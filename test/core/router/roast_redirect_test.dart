import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/core/router/app_routes.dart';
import 'package:unshrimp_app/core/router/roast_redirect.dart';

void main() {
  group('roastRedirect', () {
    test('pending forces the authed screens to the roast', () {
      for (final loc in [
        AppRoutes.home,
        AppRoutes.settings,
        AppRoutes.notifications,
        AppRoutes.changePassword,
      ]) {
        expect(roastRedirect(location: loc, pending: true), AppRoutes.roast);
      }
    });

    test('pending lets the break and the roast through', () {
      expect(roastRedirect(location: AppRoutes.breakTime, pending: true), isNull);
      expect(roastRedirect(location: AppRoutes.roast, pending: true), isNull);
    });

    test('pending leaves non-authed routes alone', () {
      expect(roastRedirect(location: AppRoutes.logIn, pending: true), isNull);
      expect(roastRedirect(location: AppRoutes.onboarding, pending: true), isNull);
    });

    test('not pending sends the roast back to Home', () {
      expect(roastRedirect(location: AppRoutes.roast, pending: false), AppRoutes.home);
    });

    test('not pending leaves the other screens alone', () {
      expect(roastRedirect(location: AppRoutes.home, pending: false), isNull);
      expect(roastRedirect(location: AppRoutes.settings, pending: false), isNull);
      expect(roastRedirect(location: AppRoutes.breakTime, pending: false), isNull);
    });
  });
}
