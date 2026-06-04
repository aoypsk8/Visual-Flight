import 'dart:math' as math;

/// Active road-trip focus session (single source of truth for the road-trip
/// live screen). Mirrors [LiveFlightSession] but models a car journey.
class RoadTripSession {
  const RoadTripSession({
    required this.fromCity,
    required this.fromCountry,
    required this.toCity,
    required this.toCountry,
    required this.seatCode,
    required this.totalKm,
    required this.totalSeconds,
    required this.startedAt,
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
    this.routeCoords = const [],
  });

  /// Origin city name (e.g. "Bangkok").
  final String fromCity;

  /// Origin country name (e.g. "Thailand").
  final String fromCountry;

  /// Destination city name.
  final String toCity;

  /// Destination country name.
  final String toCountry;

  /// Seat / role code. One of: 'DRV' (driver), 'FP' (front passenger),
  /// 'RL' (rear left), 'RC' (rear centre), 'RR' (rear right).
  final String seatCode;

  /// Total road distance in kilometres.
  final double totalKm;

  /// Estimated total driving time in seconds.
  final int totalSeconds;

  /// Wall-clock time when the session was started.
  final DateTime startedAt;

  /// Origin latitude.
  final double fromLat;

  /// Origin longitude.
  final double fromLng;

  /// Destination latitude.
  final double toLat;

  /// Destination longitude.
  final double toLng;

  /// Ordered route waypoints from Mapbox Directions: [[lon, lat], ...].
  /// When non-empty, position and bearing are interpolated along this
  /// polyline rather than great-circle.
  final List<List<double>> routeCoords;

  // ---------------------------------------------------------------------------
  // Derived helpers
  // ---------------------------------------------------------------------------

  Duration get totalDuration => Duration(seconds: totalSeconds);

  /// Normalised progress in [0, 1]; 0 = origin, 1 = destination.
  /// Millisecond-level precision.
  double progressAt(DateTime now) {
    if (totalSeconds <= 0) return 1.0;
    final elapsedMs = now.difference(startedAt).inMilliseconds;
    return (elapsedMs / (totalSeconds * 1000)).clamp(0.0, 1.0);
  }

  /// Latitude/longitude of the car at the given [progress] value.
  ///
  /// If [routeCoords] is non-empty the position is interpolated along the
  /// polyline segments by accumulated arc-length. Otherwise a simple linear
  /// interpolation between origin and destination is used (suitable as a
  /// fallback when the Directions API is unavailable).
  (double lat, double lng) positionAt(double progress) {
    final p = progress.clamp(0.0, 1.0);

    if (routeCoords.isEmpty) {
      // Linear fallback
      return (
        fromLat + (toLat - fromLat) * p,
        fromLng + (toLng - fromLng) * p,
      );
    }

    // Build cumulative distances (in degrees, good enough for interpolation).
    final coords = routeCoords;
    final n = coords.length;
    if (n == 1) return (coords[0][1], coords[0][0]);

    final cumDist = List<double>.filled(n, 0.0);
    for (var i = 1; i < n; i++) {
      final dLon = coords[i][0] - coords[i - 1][0];
      final dLat = coords[i][1] - coords[i - 1][1];
      cumDist[i] = cumDist[i - 1] + math.sqrt(dLon * dLon + dLat * dLat);
    }

    final totalDist = cumDist[n - 1];
    if (totalDist == 0) return (coords[0][1], coords[0][0]);

    final target = p * totalDist;

    // Binary search for the segment that contains [target].
    var lo = 0;
    var hi = n - 1;
    while (lo < hi - 1) {
      final mid = (lo + hi) >> 1;
      if (cumDist[mid] <= target) {
        lo = mid;
      } else {
        hi = mid;
      }
    }

    final segLen = cumDist[hi] - cumDist[lo];
    final t = segLen == 0 ? 0.0 : (target - cumDist[lo]) / segLen;

    final lon = coords[lo][0] + (coords[hi][0] - coords[lo][0]) * t;
    final lat = coords[lo][1] + (coords[hi][1] - coords[lo][1]) * t;
    return (lat, lon);
  }

  /// Bearing in degrees (0 = north, clockwise) at the given [progress],
  /// computed from the tangent direction of the route at that point.
  ///
  /// Uses a small forward delta to approximate the tangent. Useful for
  /// rotating a car icon to face the direction of travel.
  double bearingAt(double progress) {
    const delta = 0.001; // 0.1 % of the route
    final p1 = progress.clamp(0.0, 1.0);
    final p2 = (progress + delta).clamp(0.0, 1.0);

    final (lat1, lon1) = positionAt(p1);
    final (lat2, lon2) = positionAt(p2);

    if ((lat2 - lat1).abs() < 1e-9 && (lon2 - lon1).abs() < 1e-9) {
      // Already at destination — preserve last known heading.
      final pBack = (progress - delta).clamp(0.0, 1.0);
      final (latB, lonB) = positionAt(pBack);
      return _bearing(latB, lonB, lat1, lon1);
    }

    return _bearing(lat1, lon1, lat2, lon2);
  }

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'fromCity': fromCity,
        'fromCountry': fromCountry,
        'toCity': toCity,
        'toCountry': toCountry,
        'seatCode': seatCode,
        'totalKm': totalKm,
        'totalSeconds': totalSeconds,
        'startedAt': startedAt.toIso8601String(),
        'fromLat': fromLat,
        'fromLng': fromLng,
        'toLat': toLat,
        'toLng': toLng,
        'routeCoords': routeCoords,
      };

  /// Convenience constructor that mirrors [LiveFlightSession.fromBoarding].
  factory RoadTripSession.create({
    required String fromCity,
    required String fromCountry,
    required String toCity,
    required String toCountry,
    required String seatCode,
    required double distanceKm,
    required Duration duration,
    double fromLat = 0.0,
    double fromLng = 0.0,
    double toLat = 0.0,
    double toLng = 0.0,
    List<List<double>> routeCoords = const [],
    DateTime? startedAt,
  }) {
    final seconds = duration.inSeconds > 0 ? duration.inSeconds : 60;
    return RoadTripSession(
      fromCity: fromCity,
      fromCountry: fromCountry,
      toCity: toCity,
      toCountry: toCountry,
      seatCode: seatCode,
      totalKm: distanceKm,
      totalSeconds: seconds,
      startedAt: startedAt ?? DateTime.now(),
      fromLat: fromLat,
      fromLng: fromLng,
      toLat: toLat,
      toLng: toLng,
      routeCoords: routeCoords,
    );
  }

  factory RoadTripSession.fromJson(Map<String, dynamic> json) {
    // routeCoords is stored as List<List<dynamic>> in JSON; cast carefully.
    final rawCoords = json['routeCoords'];
    final routeCoords = <List<double>>[];
    if (rawCoords is List) {
      for (final item in rawCoords) {
        if (item is List && item.length >= 2) {
          routeCoords.add([
            (item[0] as num).toDouble(),
            (item[1] as num).toDouble(),
          ]);
        }
      }
    }

    return RoadTripSession(
      fromCity: json['fromCity'] as String,
      fromCountry: json['fromCountry'] as String,
      toCity: json['toCity'] as String,
      toCountry: json['toCountry'] as String,
      seatCode: json['seatCode'] as String,
      totalKm: (json['totalKm'] as num).toDouble(),
      totalSeconds: json['totalSeconds'] as int,
      startedAt: DateTime.parse(json['startedAt'] as String),
      fromLat: (json['fromLat'] as num).toDouble(),
      fromLng: (json['fromLng'] as num).toDouble(),
      toLat: (json['toLat'] as num).toDouble(),
      toLng: (json['toLng'] as num).toDouble(),
      routeCoords: routeCoords,
    );
  }

  // ---------------------------------------------------------------------------
  // Private geometry helpers
  // ---------------------------------------------------------------------------

  /// Spherical bearing from point A to point B in degrees [0, 360).
  static double _bearing(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final phi1 = _rad(lat1);
    final phi2 = _rad(lat2);
    final dLambda = _rad(lon2 - lon1);

    final y = math.sin(dLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);

    final theta = math.atan2(y, x);
    return (theta * 180 / math.pi + 360) % 360;
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
