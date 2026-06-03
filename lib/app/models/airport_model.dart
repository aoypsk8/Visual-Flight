/// Airport model — data from bundled JSON (mwgg subset).
class Airport {
  final String code;
  final String icao;
  final String city;
  final String country;
  final String countryCode;
  final String name;
  final double lat;
  final double lng;
  final int elevationFt;
  final String timezone;
  final String continent;

  const Airport({
    required this.code,
    required this.icao,
    required this.city,
    required this.country,
    required this.countryCode,
    required this.name,
    required this.lat,
    required this.lng,
    required this.elevationFt,
    required this.timezone,
    required this.continent,
  });

  /// Generic JSON map (e.g. tests or custom backend).
  factory Airport.fromJson(Map<String, dynamic> json) {
    return Airport(
      code: (json['code'] ?? json['iata'] ?? '') as String,
      icao: (json['icao'] ?? '') as String,
      city: (json['city'] ?? '') as String,
      country: (json['country'] ?? '') as String,
      countryCode: (json['countryCode'] ?? json['country'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      lat: _toDouble(json['lat'] ?? json['latitude']),
      lng: _toDouble(json['lng'] ?? json['longitude'] ?? json['lon']),
      elevationFt: _toInt(json['elevationFt'] ?? json['elevation_ft'] ?? json['elevation']),
      timezone: (json['timezone'] ?? json['tz'] ?? 'UTC') as String,
      continent: (json['continent'] ?? 'AS') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'icao': icao,
        'city': city,
        'country': country,
        'countryCode': countryCode,
        'name': name,
        'lat': lat,
        'lng': lng,
        'elevationFt': elevationFt,
        'timezone': timezone,
        'continent': continent,
      };

  /// Flag emoji from ISO 3166-1 alpha-2 country code.
  String get flagEmoji {
    final cc = countryCode.toUpperCase();
    if (cc.length != 2) return '';
    return String.fromCharCodes(
      cc.codeUnits.map((u) => 0x1F1E6 + u - 65),
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
