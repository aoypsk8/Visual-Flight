import 'package:get/get.dart';

import '../../../../controllers/search_controller.dart';

/// Which route endpoint the user is placing via map tap.
enum MapPinPickTarget { from, to }

/// Search tab route-building steps for copy and UI state.
enum SearchRouteUxStep {
  findingOrigin,
  chooseDestination,
  routeReady,
}

extension SearchRouteUxStepX on SearchRouteUxStep {
  String hint(TravelMode mode) {
    switch (this) {
      case SearchRouteUxStep.findingOrigin:
        return 'search_hint_finding_origin'.tr;
      case SearchRouteUxStep.chooseDestination:
        return mode == TravelMode.drive
            ? 'search_hint_choose_dest_drive'.tr
            : 'search_hint_choose_dest_flight'.tr;
      case SearchRouteUxStep.routeReady:
        return mode == TravelMode.drive
            ? 'search_hint_route_ready_drive'.tr
            : 'search_hint_route_ready_flight'.tr;
    }
  }

  String primaryLabel(TravelMode mode) {
    switch (this) {
      case SearchRouteUxStep.findingOrigin:
        return 'search_btn_wait'.tr;
      case SearchRouteUxStep.chooseDestination:
        return 'search_btn_choose_destination'.tr;
      case SearchRouteUxStep.routeReady:
        return 'search_btn_select_seat'.tr;
    }
  }

  bool get primaryEnabled {
    switch (this) {
      case SearchRouteUxStep.findingOrigin:
        return false;
      case SearchRouteUxStep.chooseDestination:
      case SearchRouteUxStep.routeReady:
        return true;
    }
  }
}
