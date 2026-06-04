import 'dart:convert';
import 'dart:math' as math;

/// GeoJSON line for the day/night terminator (sunset ring).
String buildTerminatorLineGeoJson([DateTime? atUtc]) {
  final utc = (atUtc ?? DateTime.now()).toUtc();
  final dec = _declinationRad(utc);
  final subLat = dec;
  final subLon = _subsolarLonRad(utc);

  final ring = <List<double>>[];
  for (var i = 0; i <= 360; i += 3) {
    final p = _destination(subLat, subLon, 90, i.toDouble());
    ring.add([p[1], p[0]]);
  }

  return jsonEncode({
    'type': 'FeatureCollection',
    'features': [
      {
        'type': 'Feature',
        'properties': {},
        'geometry': {
          'type': 'LineString',
          'coordinates': ring,
        },
      },
    ],
  });
}

/// GeoJSON fill for the night side of Earth (terminator from UTC sun position).
String buildNightSideGeoJson([DateTime? atUtc]) {
  final utc = (atUtc ?? DateTime.now()).toUtc();
  final dec = _declinationRad(utc);
  final subLat = dec;
  final subLon = _subsolarLonRad(utc);

  // Great circle 90° from subsolar point = day/night terminator.
  final ring = <List<double>>[];
  for (var i = 0; i <= 360; i += 3) {
    final p = _destination(subLat, subLon, 90, i.toDouble());
    ring.add([p[1], p[0]]); // GeoJSON [lng, lat]
  }

  // Antipode of subsolar = center of night hemisphere.
  final nightLat = -subLat;
  final nightLon = _wrapLon(subLon + math.pi);

  final polygon = <List<double>>[
    [_wrapLonDeg(nightLon), nightLat * 180 / math.pi],
    ...ring.reversed,
    [_wrapLonDeg(nightLon), nightLat * 180 / math.pi],
  ];

  return jsonEncode({
    'type': 'FeatureCollection',
    'features': [
      {
        'type': 'Feature',
        'properties': {'side': 'night'},
        'geometry': {
          'type': 'Polygon',
          'coordinates': [polygon],
        },
      },
    ],
  });
}

double _declinationRad(DateTime utc) {
  final start = DateTime.utc(utc.year, 1, 1);
  final n = utc.difference(start).inDays + 1 + utc.hour / 24.0;
  return 23.44 * math.pi / 180 * math.sin(2 * math.pi * (284 + n) / 365.25);
}

double _subsolarLonRad(DateTime utc) {
  final hours = utc.hour + utc.minute / 60.0 + utc.second / 3600.0;
  return (hours * 15.0 - 180.0) * math.pi / 180.0;
}

/// Returns [latRad, lonRad].
List<double> _destination(double latRad, double lonRad, double distDeg, double bearingDeg) {
  final d = distDeg * math.pi / 180;
  final brng = bearingDeg * math.pi / 180;
  final lat2 = math.asin(
    math.sin(latRad) * math.cos(d) +
        math.cos(latRad) * math.sin(d) * math.cos(brng),
  );
  final lon2 = lonRad +
      math.atan2(
        math.sin(brng) * math.sin(d) * math.cos(latRad),
        math.cos(d) - math.sin(latRad) * math.sin(lat2),
      );
  return [lat2, _wrapLon(lon2)];
}

double _wrapLon(double lonRad) {
  var x = lonRad;
  while (x < -math.pi) {
    x += 2 * math.pi;
  }
  while (x > math.pi) {
    x -= 2 * math.pi;
  }
  return x;
}

double _wrapLonDeg(double lonRad) => _wrapLon(lonRad) * 180 / math.pi;
