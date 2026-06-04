import '../models/airport_model.dart';
import '../services/api/airport_api_service.dart';

/// Nearest-airport lookup from the offline index.
class AirportRepository {
  AirportRepository(this._airportApi);

  final AirportApiService _airportApi;

  Future<Airport?> findNearestAirport(double lat, double lng) =>
      _airportApi.findNearest(lat, lng);

  Future<Airport?> findByIata(String iata) => _airportApi.findByIata(iata);
}
