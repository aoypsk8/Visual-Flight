import 'package:get/get.dart';

class HomeController extends GetxController {
  static HomeController get to => Get.find();

  final currentTab = 0.obs;

  void setTab(int index) => currentTab.value = index;

  void bookFlight() {
    // TODO: navigate to seat selection
  }
}
