import '../../config/api_urls.dart';
import '../../config/app_env.dart';
import '../../models/road_route_result.dart';
import 'mapbox_api_client.dart';

/// Mapbox Directions API — data source layer (MVVM: Service).
class MapboxDirectionsApiService {
  MapboxDirectionsApiService(this._client);

  final MapboxApiClient _client;

  Future<RoadRouteResult?> fetchDrivingRoute(RoadRouteRequest request) async {
    if (AppEnv.mapboxToken.isEmpty) return null;

    final json = await _client.getJson(
      MapboxApiPaths.directionsRoute(request),
      queryParameters: MapboxApiPaths.directionsDrivingGeoJson(),
    );

    return _parseRoute(json);
  }

  RoadRouteResult? _parseRoute(Map<String, dynamic>? data) {
    if (data == null) return null;

    final routes = data['routes'];
    if (routes is! List || routes.isEmpty) return null;

    final route = routes.first;
    if (route is! Map<String, dynamic>) return null;

    final geometry = route['geometry'];
    if (geometry is! Map<String, dynamic>) return null;

    final rawCoords = geometry['coordinates'];
    if (rawCoords is! List || rawCoords.isEmpty) return null;

    final coords = <List<double>>[];
    for (final item in rawCoords) {
      if (item is List && item.length >= 2) {
        coords.add([
          (item[0] as num).toDouble(),
          (item[1] as num).toDouble(),
        ]);
      }
    }
    if (coords.isEmpty) return null;

    final distanceM = (route['distance'] as num?)?.toDouble() ?? 0.0;
    final durationSec = (route['duration'] as num?)?.toDouble() ?? 0.0;

    return RoadRouteResult(
      coords: coords,
      distanceKm: distanceM / 1000.0,
      duration: Duration(seconds: durationSec.round()),
    );
  }
}
