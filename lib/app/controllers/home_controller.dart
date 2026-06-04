import 'dart:async';

import 'package:get/get.dart';
import 'search_controller.dart';

class HomeController extends GetxController {
  static HomeController get to => Get.find();

  final currentTab = 0.obs;

  void setTab(int index) {
    currentTab.value = index;
    // Sync travel mode: tab 1 = Car/Drive, tab 0 = Flight
    try {
      final search = FlightSearchController.instance;
      if (index == 1) {
        if (search.travelMode.value != TravelMode.drive) {
          search.travelMode.value = TravelMode.drive;
        } else {
          unawaited(search.refreshRoadRouteIfNeeded());
        }
      } else if (index == 0) {
        if (search.travelMode.value != TravelMode.fly) {
          search.travelMode.value = TravelMode.fly;
        } else {
          unawaited(search.refreshRoadRouteIfNeeded());
        }
      }
    } catch (_) {}
  }

  void bookFlight() {}
}
