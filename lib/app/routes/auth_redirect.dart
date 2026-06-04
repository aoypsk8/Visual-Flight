import 'package:get/get.dart';

import '../services/auth_service.dart';
import 'app_routes.dart';

/// นำทางไป login เมื่อ session หมด — ไม่รบกวนหน้า auth/onboarding
abstract final class AuthRedirect {
  AuthRedirect._();

  static const _publicRoutes = {
    AppRoutes.splash,
    AppRoutes.onboarding,
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.forgotPassword,
  };

  static bool get isOnPublicRoute => _publicRoutes.contains(Get.currentRoute);

  static void toLoginIfNeeded() {
    if (!Get.isRegistered<AuthService>()) return;
    if (AuthService.to.isLoggedIn) return;
    if (isOnPublicRoute) return;
    Get.offAllNamed(AppRoutes.login);
  }

  static void toHomeIfLoggedIn() {
    if (!Get.isRegistered<AuthService>()) return;
    if (!AuthService.to.isLoggedIn) return;
    if (Get.currentRoute == AppRoutes.home) return;
    Get.offAllNamed(AppRoutes.home);
  }
}
