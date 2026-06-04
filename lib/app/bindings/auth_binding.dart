import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../services/auth_service.dart';

/// Auth layer — Firebase [AuthService] + login/register controller
class AuthBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AuthService(), permanent: true);
    Get.lazyPut<AuthController>(() => AuthController(), fenix: true);
  }
}
