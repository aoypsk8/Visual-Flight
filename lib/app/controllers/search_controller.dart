import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../models/airport_model.dart';
import '../repositories/airport_repository.dart';
import '../services/location_service.dart';
import '../utils/flight_route_utils.dart';
import '../views/seat/seat_selection_view.dart';
import '../views/home/pages/search/airport_picker_sheet.dart';

class FlightSearchController extends GetxController {
  static FlightSearchController get instance => Get.find();

  FlightSearchController(this._locationService, this._airportRepo);

  final LocationService _locationService;
  final AirportRepository _airportRepo;

  // ── Reactive state ─────────────────────────────────────────────────────────
  /// Nearest network airport (IATA code / booking labels).
  final from = Rxn<Airport>();
  /// Raw device GPS latitude for map origin when using current location.
  final fromLat = Rxn<double>();
  final fromLng = Rxn<double>();
  final to = Rxn<Airport>(); // null until destination is chosen
  final loadingLocation = true.obs;

  /// true = route origin uses GPS; false = user picked a FROM airport manually.
  bool _fromPinnedToAirport = false;

  /// FROM is the device position, not the airport coordinates from the list.
  bool get fromIsCurrentLocation =>
      !_fromPinnedToAirport && fromLat.value != null && fromLng.value != null;

  /// Great-circle distance in km when FROM and TO are set.
  double? get routeDistanceKm {
    final dest = to.value;
    if (dest == null) return null;
    final coords = _originCoords();
    if (coords == null) return null;
    final (lat, lng) = coords;
    return FlightRouteUtils.distanceKm(lat, lng, dest.lat, dest.lng);
  }

  /// Estimated block time.
  Duration? get routeFlightDuration {
    final km = routeDistanceKm;
    if (km == null) return null;
    return FlightRouteUtils.estimatedFlightDuration(km);
  }

  bool get canContinueToSeats =>
      !loadingLocation.value && from.value != null && to.value != null;

  // ── Map state (not reactive — map API drives its own rendering) ────────────
  MapboxMap? mapCtrl;
  List<List<double>> currentArc = [];
  CircleAnnotationManager? planeAnnotMgr;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  // ── Location detection (after Mapbox puck is enabled — same order as HomeTabPage) ─

  Future<void> _resolveFromNearestAirport() async {
    loadingLocation.value = true;
    final pos = await _locationService.getCurrentPosition();
    _fromPinnedToAirport = false;
    if (pos != null) {
      fromLat.value = pos.latitude;
      fromLng.value = pos.longitude;
      from.value = await _airportRepo.findNearestAirport(
        pos.latitude,
        pos.longitude,
      );
    } else {
      fromLat.value = null;
      fromLng.value = null;
      from.value = null;
    }
    loadingLocation.value = false;
    await _syncRouteLayers();
  }

  /// Route origin coordinates — device GPS when [fromIsCurrentLocation], else airport.
  (double lat, double lng)? _originCoords() {
    final airport = from.value;
    if (airport == null) return null;
    if (fromIsCurrentLocation) {
      return (fromLat.value!, fromLng.value!);
    }
    return (airport.lat, airport.lng);
  }

  // ── Map lifecycle ──────────────────────────────────────────────────────────

  Future<void> onMapCreated(MapboxMap map) async {
    mapCtrl = map;

    await map.style.setProjection(
      StyleProjection(name: StyleProjectionName.globe),
    );
    await map.style.addLayer(
      SkyLayer(
        id: 'sky',
        skyType: SkyType.ATMOSPHERE,
        skyAtmosphereSun: [0.0, 90.0],
        skyAtmosphereSunIntensity: 15.0,
      ),
    );

    // Device location puck (amber pulse) — matches HomeTabPage
    await map.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingColor: 0xFFF6A93B,
        locationPuck: LocationPuck(locationPuck2D: DefaultLocationPuck2D()),
      ),
    );

    currentArc = _greatCircleArc();
    await map.style.addSource(
      GeoJsonSource(id: 'route-src', data: _buildRouteGeoJson()),
    );

    await map.style.addLayer(
      LineLayer(
        id: 'route-glow',
        sourceId: 'route-src',
        lineColor: const Color(0xFFF6A93B).toARGB32(),
        lineWidth: 22.0,
        lineOpacity: 0.10,
        lineBlur: 10.0,
      ),
    );
    await map.style.addLayer(
      LineLayer(
        id: 'route-core-glow',
        sourceId: 'route-src',
        lineColor: const Color(0xFFF6A93B).toARGB32(),
        lineWidth: 8.0,
        lineOpacity: 0.22,
        lineBlur: 3.0,
      ),
    );
    await map.style.addLayer(
      LineLayer(
        id: 'route-main',
        sourceId: 'route-src',
        lineColor: const Color(0xFFF6A93B).toARGB32(),
        lineWidth: 2.6,
        lineOpacity: 0.95,
      ),
    );
    await map.style.addLayer(
      LineLayer(
        id: 'route-dashes',
        sourceId: 'route-src',
        lineColor: Colors.white.toARGB32(),
        lineWidth: 1.5,
        lineOpacity: 0.45,
        lineDasharray: [5.0, 6.0],
      ),
    );

    await map.style.addSource(
      GeoJsonSource(id: 'airports-src', data: _buildAirportGeoJson()),
    );

    await map.style.addLayer(
      CircleLayer(
        id: 'from-halo',
        sourceId: 'airports-src',
        filter: [
          '==',
          ['get', 'kind'],
          'from',
        ],
        circleRadius: 20.0,
        circleColor: const Color(0xFFF6A93B).toARGB32(),
        circleOpacity: 0.18,
      ),
    );
    await map.style.addLayer(
      CircleLayer(
        id: 'from-dot',
        sourceId: 'airports-src',
        filter: [
          '==',
          ['get', 'kind'],
          'from',
        ],
        circleRadius: 9.0,
        circleColor: const Color(0xFFF6A93B).toARGB32(),
        circleStrokeWidth: 2.5,
        circleStrokeColor: Colors.white.toARGB32(),
      ),
    );
    await map.style.addLayer(
      CircleLayer(
        id: 'to-halo',
        sourceId: 'airports-src',
        filter: [
          '==',
          ['get', 'kind'],
          'to',
        ],
        circleRadius: 20.0,
        circleColor: Colors.white.toARGB32(),
        circleOpacity: 0.12,
      ),
    );
    await map.style.addLayer(
      CircleLayer(
        id: 'to-dot',
        sourceId: 'airports-src',
        filter: [
          '==',
          ['get', 'kind'],
          'to',
        ],
        circleRadius: 9.0,
        circleColor: Colors.white.toARGB32(),
        circleStrokeWidth: 2.5,
        circleStrokeColor: const Color(0xFFF6A93B).toARGB32(),
      ),
    );
    await map.style.addLayer(
      SymbolLayer(
        id: 'airport-labels',
        sourceId: 'airports-src',
        textField: '{code}',
        textSize: 13.0,
        textColor: Colors.white.toARGB32(),
        textHaloColor: Colors.black.toARGB32(),
        textHaloWidth: 2.0,
        textOffset: [0.0, 2.4],
      ),
    );

    planeAnnotMgr = await map.annotations.createCircleAnnotationManager();
    if (currentArc.isNotEmpty) {
      final start = Point(
        coordinates: Position(currentArc[0][0], currentArc[0][1]),
      );
      await planeAnnotMgr!.create(
        CircleAnnotationOptions(
          geometry: start,
          circleRadius: 18.0,
          circleColor: const Color(0xFFF6A93B).toARGB32(),
          circleOpacity: 0.20,
        ),
      );
      await planeAnnotMgr!.create(
        CircleAnnotationOptions(
          geometry: start,
          circleRadius: 6.5,
          circleColor: Colors.white.toARGB32(),
          circleStrokeWidth: 2.2,
          circleStrokeColor: const Color(0xFFF6A93B).toARGB32(),
        ),
      );
    }

    await _resolveFromNearestAirport();
  }

  Future<void> _syncRouteLayers() async {
    final map = mapCtrl;
    if (map == null) return;
    currentArc = _greatCircleArc();
    try {
      await map.style.setStyleSourceProperty(
        'route-src',
        'data',
        _buildRouteGeoJson(),
      );
      await map.style.setStyleSourceProperty(
        'airports-src',
        'data',
        _buildAirportGeoJson(),
      );
    } catch (_) {}
  }

  Future<void> _updateRoute() async {
    await _syncRouteLayers();
    if (to.value != null) {
      await _fitCamera(animate: true);
    }
  }

  Future<void> _fitCamera({required bool animate}) async {
    final map = mapCtrl;
    final coords = _originCoords();
    if (map == null || coords == null) return;
    final (originLat, originLng) = coords;
    final dest = to.value;
    final CameraOptions opts;

    if (dest == null) {
      opts = CameraOptions(
        center: Point(coordinates: Position(originLng, originLat)),
        zoom: 7.0,
        pitch: 28.0,
        bearing: 0.0,
      );
    } else {
      final midLat = (originLat + dest.lat) / 2;
      final midLng = (originLng + dest.lng) / 2;
      final span = math.max(
        (originLat - dest.lat).abs(),
        (originLng - dest.lng).abs(),
      );
      final zoom = span < 3
          ? 8.0
          : span < 8
          ? 6.5
          : span < 15
          ? 5.5
          : span < 30
          ? 4.5
          : 4.0;
      opts = CameraOptions(
        center: Point(coordinates: Position(midLng, midLat)),
        zoom: zoom,
        pitch: 28.0,
        bearing: 0.0,
      );
    }

    if (animate) {
      await map.flyTo(opts, MapAnimationOptions(duration: 700));
    } else {
      await map.setCamera(opts);
    }
  }

  // ── GeoJSON builders ───────────────────────────────────────────────────────

  String _buildAirportGeoJson() {
    final origin = from.value;
    final coords = _originCoords();
    final dest = to.value;
    if (origin == null || coords == null) {
      return jsonEncode({'type': 'FeatureCollection', 'features': []});
    }
    final (originLat, originLng) = coords;
    final features = <Map<String, dynamic>>[
      {
        'type': 'Feature',
        'properties': {
          'code': fromIsCurrentLocation ? 'GPS' : origin.code,
          'kind': 'from',
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [originLng, originLat],
        },
      },
    ];
    if (dest != null) {
      features.add({
        'type': 'Feature',
        'properties': {'code': dest.code, 'kind': 'to'},
        'geometry': {
          'type': 'Point',
          'coordinates': [dest.lng, dest.lat],
        },
      });
    }
    return jsonEncode({'type': 'FeatureCollection', 'features': features});
  }

  String _buildRouteGeoJson() => jsonEncode({
    'type': 'FeatureCollection',
    'features': currentArc.isEmpty
        ? []
        : [
            {
              'type': 'Feature',
              'properties': {},
              'geometry': {'type': 'LineString', 'coordinates': currentArc},
            },
          ],
  });

  List<List<double>> _greatCircleArc({int n = 60}) {
    final coords = _originCoords();
    final dest = to.value;
    if (coords == null || dest == null) return [];

    final (originLat, originLng) = coords;
    final r1 = originLat * math.pi / 180;
    final o1 = originLng * math.pi / 180;
    final r2 = dest.lat * math.pi / 180;
    final o2 = dest.lng * math.pi / 180;
    final d =
        2 *
        math.asin(
          math.sqrt(
            math.pow(math.sin((r2 - r1) / 2), 2) +
                math.cos(r1) *
                    math.cos(r2) *
                    math.pow(math.sin((o2 - o1) / 2), 2),
          ),
        );
    if (d < 0.0001) {
      return [
        [originLng, originLat],
        [dest.lng, dest.lat],
      ];
    }

    final pts = <List<double>>[];
    for (int i = 0; i <= n; i++) {
      final t = i / n;
      final A = math.sin((1 - t) * d) / math.sin(d);
      final B = math.sin(t * d) / math.sin(d);
      final x =
          A * math.cos(r1) * math.cos(o1) + B * math.cos(r2) * math.cos(o2);
      final y =
          A * math.cos(r1) * math.sin(o1) + B * math.cos(r2) * math.sin(o2);
      final z = A * math.sin(r1) + B * math.sin(r2);
      final lat = math.atan2(z, math.sqrt(x * x + y * y)) * 180 / math.pi;
      final lng = math.atan2(y, x) * 180 / math.pi;
      pts.add([lng, lat]);
    }
    return pts;
  }

  // ── User interactions ──────────────────────────────────────────────────────

  void swap() {
    final origin = from.value;
    final dest = to.value;
    if (origin == null || dest == null) return;
    HapticFeedback.lightImpact();
    _fromPinnedToAirport = true;
    fromLat.value = null;
    fromLng.value = null;
    from.value = dest;
    to.value = origin;
    _updateRoute();
  }

  Future<void> pickAirport({required bool isFrom}) async {
    final result = await showModalBottomSheet<Airport>(
      context: Get.context!,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AirportPickerSheet(
        selected: isFrom ? from.value : to.value,
        exclude: isFrom ? to.value : from.value,
      ),
    );
    if (result == null) return;
    if (isFrom) {
      _fromPinnedToAirport = true;
      fromLat.value = null;
      fromLng.value = null;
      from.value = result;
    } else {
      to.value = result;
    }
    await _updateRoute();
  }

  void openSeatSelection() {
    if (!canContinueToSeats) return;
    final origin = from.value!;
    final dest = to.value!;
    HapticFeedback.mediumImpact();
    Get.to(
      () => SeatSelectionView(
        fromCode: origin.code,
        fromCity: origin.city,
        toCode: dest.code,
        toCity: dest.city,
      ),
    );
  }
}
