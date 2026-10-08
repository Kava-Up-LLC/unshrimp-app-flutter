import 'app_routes.dart';

/// Where go_router should send the user given the current [location] and
/// whether a roast is [pending]. While pending, the authed screens are forced
/// to the roast, the break is let through (the only way out), and the roast
/// itself stays; when it clears, the roast returns to Home. Null = no redirect.
String? roastRedirect({required String location, required bool pending}) {
  const gated = {
    AppRoutes.home,
    AppRoutes.settings,
    AppRoutes.notifications,
    AppRoutes.changePassword,
  };
  if (pending) {
    if (location == AppRoutes.roast || location == AppRoutes.breakTime) {
      return null;
    }
    return gated.contains(location) ? AppRoutes.roast : null;
  }
  return location == AppRoutes.roast ? AppRoutes.home : null;
}
