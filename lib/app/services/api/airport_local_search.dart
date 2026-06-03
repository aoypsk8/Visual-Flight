import 'dart:math' as math;

import '../../models/airport_model.dart';
import 'airport_search_index_store.dart';

/// Offline airport search using contains/startsWith/Levenshtein matching.
class AirportLocalSearch {
  AirportLocalSearch._();

  static const _defaultLimit = 40;

  /// Results sorted by relevance (highest score first).
  static Future<List<Airport>> search(
    String query, {
    int limit = _defaultLimit,
  }) async {
    await AirportSearchIndexStore.instance.ensureReady();
    final index = AirportSearchIndexStore.instance.airports;

    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];

    final tokens = q.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
    if (tokens.isEmpty && q.length < 2) return [];

    final aliasCodes = await iataCodesForCity(q);
    final aliasSet = aliasCodes.toSet();

    final scored = <_Scored>[];
    for (final airport in index) {
      if (aliasSet.contains(airport.code)) {
        scored.add(_Scored(airport, 1.0));
        continue;
      }
      final score = _scoreAirport(airport, q, tokens);
      if (score > 0) scored.add(_Scored(airport, score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    final seen = <String>{};
    final out = <Airport>[];
    for (final s in scored) {
      if (seen.add(s.airport.code)) out.add(s.airport);
      if (out.length >= limit) break;
    }
    return out;
  }

  static Future<List<String>> iataCodesForCity(String query) async {
    await AirportSearchIndexStore.instance.ensureReady();
    final aliases = AirportSearchIndexStore.instance.cityAliases;

    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final direct = aliases[q];
    if (direct != null) return direct;

    final codes = <String>[];
    for (final entry in aliases.entries) {
      final key = entry.key;
      if (key == q ||
          key.startsWith(q) ||
          q.startsWith(key) ||
          key.contains(q) ||
          q.contains(key)) {
        codes.addAll(entry.value);
      }
    }
    return codes.toSet().toList();
  }

  static Future<Airport?> nearest(double lat, double lng) async {
    await AirportSearchIndexStore.instance.ensureReady();
    final index = AirportSearchIndexStore.instance.airports;
    if (index.isEmpty) return null;

    Airport? best;
    var bestKm = double.infinity;
    for (final a in index) {
      final d = _haversineKm(lat, lng, a.lat, a.lng);
      if (d < bestKm) {
        bestKm = d;
        best = a;
      }
    }
    return best;
  }

  static double _scoreAirport(Airport a, String q, List<String> tokens) {
    var best = _scoreField(a, q);
    for (final t in tokens) {
      final s = _scoreField(a, t);
      if (s > best) best = s;
    }
    return best;
  }

  static double _scoreField(Airport a, String q) {
    if (q.isEmpty) return 0;

    final code = a.code.toLowerCase();
    final city = a.city.toLowerCase();
    final name = a.name.toLowerCase();
    final country = a.country.toLowerCase();
    final icao = a.icao.toLowerCase();

    if (code == q || city == q || country == q) return 1.0;

    if (code.startsWith(q) || city.startsWith(q) || country.startsWith(q)) {
      return 0.95;
    }
    if (name.startsWith(q)) return 0.92;

    if (city.contains(q) || name.contains(q) || country.contains(q)) {
      return 0.88;
    }
    if (q.length <= 3 && code.startsWith(q)) return 0.9;
    if (q.length == 4 && icao.startsWith(q)) return 0.85;

    // Fuzzy match on city/name only for longer queries.
    if (q.length >= 4) {
      final citySim = _levenshteinRatio(q, city);
      final nameSim = _levenshteinRatio(q, name);
      final countrySim = _levenshteinRatio(q, country);
      final bestSim = [citySim, nameSim, countrySim].reduce(math.max);
      if (bestSim >= 0.72) return 0.7 + bestSim * 0.25;
    }

    return 0;
  }

  /// Returns 0 for no match, 1 for identical strings.
  static double _levenshteinRatio(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;
    final dist = _levenshtein(a, b);
    final maxLen = math.max(a.length, b.length);
    return 1 - dist / maxLen;
  }

  static int _levenshtein(String a, String b) {
    final m = a.length;
    final n = b.length;
    if (m == 0) return n;
    if (n == 0) return m;

    var prev = List<int>.generate(n + 1, (j) => j);
    for (var i = 1; i <= m; i++) {
      final cur = List<int>.filled(n + 1, 0);
      cur[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        cur[j] = math.min(
          math.min(cur[j - 1] + 1, prev[j] + 1),
          prev[j - 1] + cost,
        );
      }
      prev = cur;
    }
    return prev[n];
  }

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final ha = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(ha), math.sqrt(1 - ha));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}

class _Scored {
  _Scored(this.airport, this.score);
  final Airport airport;
  final double score;
}
