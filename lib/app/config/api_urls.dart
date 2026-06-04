import 'app_env.dart';
import '../models/road_route_result.dart';

/// Central URL definitions for the project — `import '.../config/api_urls.dart';`
///
/// - [ApiHosts] — Dio base URLs
/// - [AuthPaths] — backend auth paths
/// - [MapboxApiPaths] — Mapbox REST paths + query params
/// - [MapboxResourceUris] — `mapbox://` URIs for SDK (style, DEM)

// ── Base hosts ───────────────────────────────────────────────────────────────

abstract final class ApiHosts {
  ApiHosts._();

  /// FocusFlight backend — from `.env` → `API_BASE_URL`
  static String get focusFlight => AppEnv.baseUrl;

  /// Mapbox REST API
  static const mapbox = 'https://api.mapbox.com';
}

// ── FocusFlight paths (relative to [ApiHosts.focusFlight]) ───────────────────

abstract final class AuthPaths {
  AuthPaths._();

  static const login = '/auth/login';
  static const register = '/auth/register';
  static const forgotPassword = '/auth/forgot-password';
  static const logout = '/auth/logout';
}

// ── Mapbox REST (relative to [ApiHosts.mapbox]) ──────────────────────────────

abstract final class MapboxApiPaths {
  MapboxApiPaths._();

  static const directionsVersion = 'v5';
  static const profileDrivingTraffic = 'driving-traffic';

  /// `GET /directions/v5/mapbox/driving-traffic/{lon},{lat};{lon},{lat}`
  static String directionsRoute(RoadRouteRequest request) {
    final waypoints = [
      _formatCoord(request.fromLng, request.fromLat),
      _formatCoord(request.toLng, request.toLat),
    ].join(';');

    return '/directions/$directionsVersion/mapbox/'
        '$profileDrivingTraffic/$waypoints';
  }

  /// Query params for Directions (GeoJSON polyline)
  static Map<String, dynamic> directionsDrivingGeoJson({
    String? accessToken,
  }) {
    final token = accessToken ?? AppEnv.mapboxToken;
    return {
      'geometries': 'geojson',
      'overview': 'full',
      if (token.isNotEmpty) 'access_token': token,
    };
  }

  static String _formatCoord(double lng, double lat) {
    final lon = double.parse(lng.toStringAsFixed(6));
    final latitude = double.parse(lat.toStringAsFixed(6));
    return '$lon,$latitude';
  }
}

// ── Mapbox SDK resource URIs ─────────────────────────────────────────────────

abstract final class MapboxResourceUris {
  MapboxResourceUris._();

  static const satelliteStreetsV12 =
      'mapbox://styles/mapbox/satellite-streets-v12';
  static const navigationNightV1 =
      'mapbox://styles/mapbox/navigation-night-v1';
  static const terrainDemV1 = 'mapbox://mapbox.mapbox-terrain-dem-v1';
}
