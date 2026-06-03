import 'package:get/get.dart';
import '../services/api_client.dart';
import 'auth_binding.dart';

// App-wide dependencies at startup (non-feature specific).
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(ApiClient.create(), permanent: true);

    AuthBinding().dependencies();
  }
}
