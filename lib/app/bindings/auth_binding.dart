import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../repositories/auth_repository.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

/// Auth layer — repository, service, login/register controller
class AuthBinding extends Bindings {
  @override
  void dependencies() {
    final client = Get.find<ApiClient>();

    Get.put(AuthRepository(client), permanent: true);
    Get.put(AuthService(Get.find<AuthRepository>()), permanent: true);
    Get.lazyPut<AuthController>(() => AuthController(), fenix: true);
  }
}
