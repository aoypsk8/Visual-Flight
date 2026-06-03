import '../../config/airport_network.dart';
import '../../models/airport_model.dart';
import 'airport_local_search.dart';
import 'airport_search_index_store.dart';

/// Airports — search and nearest lookup from bundled JSON only.
class AirportApiService {
  static const _minSearchLength = 2;

  Future<List<Airport>> popularAirports({int limit = 24}) =>
      AirportSearchIndexStore.instance.byIataCodes(
        kPopularPickerIata,
        limit: limit,
      );

  Future<List<Airport>> search(String query) async {
    final q = query.trim();
    if (q.length < _minSearchLength) return [];
    await AirportSearchIndexStore.instance.ensureReady();
    return AirportLocalSearch.search(q);
  }

  Future<Airport?> findNearest(double lat, double lng) async {
    await AirportSearchIndexStore.instance.ensureReady();
    return AirportLocalSearch.nearest(lat, lng);
  }
}
