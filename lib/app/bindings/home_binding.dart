import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../controllers/search_controller.dart';
import '../repositories/airport_repository.dart';
import '../repositories/road_route_repository.dart';
import '../services/api/airport_api_service.dart';
import '../services/api/mapbox_api_client.dart';
import '../services/api/mapbox_directions_api_service.dart';
import '../services/location_service.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(() => HomeController());

    Get.put<LocationService>(LocationService(), permanent: true);
    Get.lazyPut<AirportApiService>(() => AirportApiService(), fenix: true);
    Get.put<AirportRepository>(
      AirportRepository(Get.find<AirportApiService>()),
      permanent: true,
    );

    Get.lazyPut<MapboxApiClient>(MapboxApiClient.create, fenix: true);
    Get.lazyPut<MapboxDirectionsApiService>(
      () => MapboxDirectionsApiService(Get.find<MapboxApiClient>()),
      fenix: true,
    );
    Get.put<RoadRouteRepository>(
      RoadRouteRepository(Get.find<MapboxDirectionsApiService>()),
      permanent: true,
    );

    Get.lazyPut<FlightSearchController>(
      () => FlightSearchController(
        Get.find<LocationService>(),
        Get.find<AirportRepository>(),
        Get.find<RoadRouteRepository>(),
      ),
    );
  }
}
