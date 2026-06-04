import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/auth_service.dart';
import 'app_routes.dart';

/// หน้า home ต้อง login ก่อน
class RequireAuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (!Get.isRegistered<AuthService>() || !AuthService.to.isLoggedIn) {
      return const RouteSettings(name: AppRoutes.login);
    }
    return null;
  }
}

/// หน้า login/register — ถ้า login แล้วส่งไป home
class RedirectIfAuthedMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (Get.isRegistered<AuthService>() && AuthService.to.isLoggedIn) {
      return const RouteSettings(name: AppRoutes.home);
    }
    return null;
  }
}
