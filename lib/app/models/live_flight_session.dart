/// Active focus-session flight (single source of truth for live screen).
class LiveFlightSession {
  const LiveFlightSession({
    required this.fromCode,
    required this.fromCity,
    required this.toCode,
    required this.toCity,
    required this.seatCode,
    required this.totalKm,
    required this.totalSeconds,
    required this.startedAt,
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
  });

  final String fromCode;
  final String fromCity;
  final String toCode;
  final String toCity;
  final String seatCode;
  final double totalKm;
  final int totalSeconds;
  final DateTime startedAt;
  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;

  bool get hasMapCoords =>
      fromLat != null &&
      fromLng != null &&
      toLat != null &&
      toLng != null;

  Duration get totalDuration => Duration(seconds: totalSeconds);

  /// Normalized progress 0 = origin, 1 = destination (millisecond precision).
  double progressAt(DateTime now) {
    if (totalSeconds <= 0) return 1.0;
    final elapsedMs = now.difference(startedAt).inMilliseconds;
    return (elapsedMs / (totalSeconds * 1000)).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'fromCode': fromCode,
        'fromCity': fromCity,
        'toCode': toCode,
        'toCity': toCity,
        'seatCode': seatCode,
        'totalKm': totalKm,
        'totalSeconds': totalSeconds,
        'startedAt': startedAt.toIso8601String(),
        'fromLat': fromLat,
        'fromLng': fromLng,
        'toLat': toLat,
        'toLng': toLng,
      };

  factory LiveFlightSession.fromJson(Map<String, dynamic> json) {
    return LiveFlightSession(
      fromCode: json['fromCode'] as String,
      fromCity: json['fromCity'] as String,
      toCode: json['toCode'] as String,
      toCity: json['toCity'] as String,
      seatCode: json['seatCode'] as String,
      totalKm: (json['totalKm'] as num).toDouble(),
      totalSeconds: json['totalSeconds'] as int,
      startedAt: DateTime.parse(json['startedAt'] as String),
      fromLat: (json['fromLat'] as num?)?.toDouble(),
      fromLng: (json['fromLng'] as num?)?.toDouble(),
      toLat: (json['toLat'] as num?)?.toDouble(),
      toLng: (json['toLng'] as num?)?.toDouble(),
    );
  }

  factory LiveFlightSession.fromBoarding({
    required String fromCode,
    required String fromCity,
    required String toCode,
    required String toCity,
    required String seatCode,
    required double distanceKm,
    required Duration flightDuration,
    double? fromLat,
    double? fromLng,
    double? toLat,
    double? toLng,
    DateTime? startedAt,
  }) {
    final seconds = flightDuration.inSeconds > 0
        ? flightDuration.inSeconds
        : 60;
    return LiveFlightSession(
      fromCode: fromCode,
      fromCity: fromCity,
      toCode: toCode,
      toCity: toCity,
      seatCode: seatCode,
      totalKm: distanceKm,
      totalSeconds: seconds,
      startedAt: startedAt ?? DateTime.now(),
      fromLat: fromLat,
      fromLng: fromLng,
      toLat: toLat,
      toLng: toLng,
    );
  }
}
