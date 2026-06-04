/// Driving route from Mapbox Directions (domain model).
class RoadRouteResult {
  const RoadRouteResult({
    required this.coords,
    required this.distanceKm,
    required this.duration,
  });

  /// GeoJSON order: [[longitude, latitude], ...]
  final List<List<double>> coords;
  final double distanceKm;
  final Duration duration;
}

/// Origin / destination for a directions request.
class RoadRouteRequest {
  const RoadRouteRequest({
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
  });

  final double fromLat;
  final double fromLng;
  final double toLat;
  final double toLng;
}
