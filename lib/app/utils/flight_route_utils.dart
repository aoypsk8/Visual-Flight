import 'dart:math' as math;

/// Great-circle distance and estimated block time (offline).
class FlightRouteUtils {
  FlightRouteUtils._();

  static const earthRadiusKm = 6371.0;

  /// Average cruise speed + ground time (taxi/climb/descent).
  static const cruiseSpeedKmh = 850.0;
  static const groundMinutes = 35;

  /// Distance in km between two coordinates (Haversine).
  static double distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Approximate block time (not a real airline schedule).
  static Duration estimatedFlightDuration(double distanceKm) {
    final cruiseMin = (distanceKm / cruiseSpeedKmh) * 60;
    return Duration(minutes: (cruiseMin + groundMinutes).round());
  }

  static String formatDistance(double km) {
    final rounded = km.round();
    if (rounded >= 1000) {
      final s = rounded.toString();
      final buf = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
        buf.write(s[i]);
      }
      return '${buf.toString()} km';
    }
    return '$rounded km';
  }

  static String formatDurationCompact(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
