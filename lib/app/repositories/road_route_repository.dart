import '../models/road_route_result.dart';
import '../services/api/mapbox_directions_api_service.dart';

/// Road routing — repository between ViewModel and Mapbox API (MVVM).
class RoadRouteRepository {
  RoadRouteRepository(this._directionsApi);

  final MapboxDirectionsApiService _directionsApi;

  /// Average speed used for focus-drive session duration (not Mapbox traffic ETA)
  static const double focusDriveSpeedKmh = 150.0;

  Future<RoadRouteResult?> fetchDrivingRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    return _directionsApi.fetchDrivingRoute(
      RoadRouteRequest(
        fromLat: fromLat,
        fromLng: fromLng,
        toLat: toLat,
        toLng: toLng,
      ),
    );
  }

  /// Focus duration estimate from road distance (km)
  Duration estimateFocusDuration(double km) {
    if (km <= 0) return Duration.zero;
    return Duration(
      seconds: (km / focusDriveSpeedKmh * 3600).round().clamp(60, 86400),
    );
  }
}
