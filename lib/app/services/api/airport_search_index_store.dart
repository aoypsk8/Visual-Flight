import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/airport_model.dart';

/// Offline search index loaded from [assets/data/airport_search_index.json].
class AirportSearchIndexStore {
  AirportSearchIndexStore._();

  static final AirportSearchIndexStore instance = AirportSearchIndexStore._();

  static const _assetPath = 'assets/data/airport_search_index.json';

  late _AirportIndex _index = _AirportIndex.empty();
  Map<String, List<String>> _cityAliases = {};
  bool _ready = false;
  Future<void>? _initFuture;

  List<Airport> get airports => _index.all;

  Airport? airportByCode(String code) => _index.byCode(code);

  Map<String, List<String>> get cityAliases => _cityAliases;

  Future<void> ensureReady() async {
    if (_ready) return;
    _initFuture ??= _load();
    await _initFuture;
  }

  Future<List<Airport>> byIataCodes(
    List<String> codes, {
    int limit = 24,
  }) async {
    await ensureReady();
    final out = <Airport>[];
    for (final raw in codes) {
      final a = _index.byCode(raw);
      if (a != null) out.add(a);
      if (out.length >= limit) break;
    }
    return out;
  }

  Future<void> _load() async {
    final byCode = <String, Airport>{};

    try {
      final raw = await rootBundle.loadString(_assetPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _parseAliases(decoded['cityAliases']);
      for (final item in decoded['airports'] as List<dynamic>? ?? []) {
        final a = Airport.fromJson(item as Map<String, dynamic>);
        if (a.code.isNotEmpty) byCode[a.code] = a;
      }
    } catch (_) {
      _cityAliases = {};
    }

    _index = _AirportIndex(byCode);
    _ready = true;
  }

  void _parseAliases(dynamic raw) {
    _cityAliases = {};
    if (raw is! Map) return;
    raw.forEach((key, value) {
      if (value is List) {
        _cityAliases[key.toString().toLowerCase()] =
            value.map((e) => e.toString().toUpperCase()).toList();
      }
    });
  }
}

class _AirportIndex {
  _AirportIndex(this._byCode);

  factory _AirportIndex.empty() => _AirportIndex({});

  final Map<String, Airport> _byCode;

  List<Airport> get all {
    final list = _byCode.values.toList()
      ..sort((a, b) => a.city.compareTo(b.city));
    return list;
  }

  Airport? byCode(String code) => _byCode[code.toUpperCase()];
}
