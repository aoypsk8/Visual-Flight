import 'dart:math' as math;

/// Great-circle polyline for map route / plane interpolation.
List<List<double>> buildGreatCircleArc({
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
  int segments = 60,
}) {
  final r1 = fromLat * math.pi / 180;
  final o1 = fromLng * math.pi / 180;
  final r2 = toLat * math.pi / 180;
  final o2 = toLng * math.pi / 180;
  final d = 2 *
      math.asin(
        math.sqrt(
          math.pow(math.sin((r2 - r1) / 2), 2) +
              math.cos(r1) * math.cos(r2) * math.pow(math.sin((o2 - o1) / 2), 2),
        ),
      );
  if (d < 0.0001) {
    return [
      [fromLng, fromLat],
      [toLng, toLat],
    ];
  }

  final pts = <List<double>>[];
  for (int i = 0; i <= segments; i++) {
    final t = i / segments;
    final a = math.sin((1 - t) * d) / math.sin(d);
    final b = math.sin(t * d) / math.sin(d);
    final x = a * math.cos(r1) * math.cos(o1) + b * math.cos(r2) * math.cos(o2);
    final y = a * math.cos(r1) * math.sin(o1) + b * math.cos(r2) * math.sin(o2);
    final z = a * math.sin(r1) + b * math.sin(r2);
    final lat = math.atan2(z, math.sqrt(x * x + y * y)) * 180 / math.pi;
    final lng = math.atan2(y, x) * 180 / math.pi;
    pts.add([lng, lat]);
  }
  return pts;
}

/// Position along arc at progress ∈ [0, 1]. Returns [lng, lat].
List<double> positionOnArc(List<List<double>> arc, double progress) {
  if (arc.isEmpty) return [0, 0];
  if (arc.length == 1) return arc.first;
  final t = progress.clamp(0.0, 1.0);
  final idx = t * (arc.length - 1);
  final i = idx.floor();
  final f = idx - i;
  if (i >= arc.length - 1) return arc.last;
  final a = arc[i];
  final b = arc[i + 1];
  return [
    a[0] + (b[0] - a[0]) * f,
    a[1] + (b[1] - a[1]) * f,
  ];
}

List<List<double>> arcSlice(List<List<double>> arc, double progress) {
  if (arc.isEmpty) return [];
  if (progress <= 0) return [arc.first];
  if (progress >= 1) return List.from(arc);
  final end = positionOnArc(arc, progress);
  final t = progress.clamp(0.0, 1.0);
  final idx = (t * (arc.length - 1)).ceil().clamp(1, arc.length - 1);
  return [...arc.sublist(0, idx), end];
}

/// Bearing in degrees (0 = north, clockwise) along the route at [progress].
double bearingOnArc(List<List<double>> arc, double progress) {
  if (arc.length < 2) return 0;
  final p = progress.clamp(0.0, 1.0);
  final a = positionOnArc(arc, p);
  final b = positionOnArc(arc, (p + 0.008).clamp(0.0, 1.0));
  final lat1 = a[1] * math.pi / 180;
  final lat2 = b[1] * math.pi / 180;
  final dLng = (b[0] - a[0]) * math.pi / 180;
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}
