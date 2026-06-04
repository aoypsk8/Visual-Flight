import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../models/airport_model.dart';
import '../repositories/airport_repository.dart';
import '../repositories/road_route_repository.dart';
import '../services/location_service.dart';
import '../utils/flight_route_utils.dart';
import '../views/road/road_seat_view.dart';
import '../views/seat/seat_selection_view.dart';
import '../views/home/tabs/search/airport_picker_sheet.dart';
import '../views/home/tabs/search/search_route_ux.dart';

enum TravelMode { fly, drive }

class FlightSearchController extends GetxController {
  static FlightSearchController get instance => Get.find();

  FlightSearchController(
    this._locationService,
    this._airportRepo,
    this._roadRouteRepo,
  );

  final LocationService _locationService;
  final AirportRepository _airportRepo;
  final RoadRouteRepository _roadRouteRepo;

  // ── Reactive state ─────────────────────────────────────────────────────────
  final travelMode = TravelMode.fly.obs;

  void toggleTravelMode() {
    travelMode.value = travelMode.value == TravelMode.fly
        ? TravelMode.drive
        : TravelMode.fly;
    HapticFeedback.selectionClick();
  }

  /// Mapbox driving polyline [[lon, lat], ...] for Car tab / live trip.
  final roadRouteCoords = <List<double>>[].obs;
  final roadDistanceKm = Rxn<double>();
  final roadDuration = Rxn<Duration>();
  final loadingRoadRoute = false.obs;

  int _roadFetchGen = 0;

  /// Distance/duration shown on card — fly = great-circle, drive = Directions API
  double? get displayDistanceKm =>
      travelMode.value == TravelMode.drive
          ? (roadDistanceKm.value ?? routeDistanceKm)
          : routeDistanceKm;

  Duration? get displayDuration =>
      travelMode.value == TravelMode.drive
          ? (roadDuration.value ??
              (routeDistanceKm != null
                  ? _roadRouteRepo.estimateFocusDuration(routeDistanceKm!)
                  : null))
          : routeFlightDuration;

  bool get canOpenRoadSeats =>
      canContinueToSeats &&
      !loadingRoadRoute.value &&
      roadRouteCoords.isNotEmpty &&
      (roadDistanceKm.value ?? 0) > 0 &&
      (roadDuration.value?.inSeconds ?? 0) > 0;

  bool get primaryActionEnabled {
    switch (routeUxStep) {
      case SearchRouteUxStep.findingOrigin:
        return false;
      case SearchRouteUxStep.chooseDestination:
        return true;
      case SearchRouteUxStep.routeReady:
        return travelMode.value == TravelMode.drive
            ? canOpenRoadSeats
            : true;
    }
  }

  @override
  void onInit() {
    super.onInit();
    ever(travelMode, (_) => unawaited(_onTravelModeChanged()));
    // ไม่รอ Mapbox — ดึง GPS ทันที (เดิมรอ style โหลดจึงค้าง "Detecting location…")
    unawaited(_resolveFromNearestAirport());
  }

  /// Called from Home tab to refresh route when switching Flight ↔ Car
  Future<void> refreshRoadRouteIfNeeded() async {
    if (travelMode.value == TravelMode.drive && to.value != null) {
      await _refreshRoadRoute();
    } else {
      await _syncRouteLayers();
    }
  }

  Future<void> _onTravelModeChanged() async {
    if (travelMode.value == TravelMode.drive && to.value != null) {
      await _refreshRoadRoute();
    } else {
      await _syncRouteLayers();
      if (to.value != null) await _fitCamera(animate: true);
    }
  }

  /// Nearest network airport (IATA code / booking labels).
  final from = Rxn<Airport>();
  /// Raw device GPS latitude for map origin when using current location.
  final fromLat = Rxn<double>();
  final fromLng = Rxn<double>();
  final to = Rxn<Airport>(); // null until destination is chosen
  /// Map pin coordinates for TO (when [_toIsMapPin]).
  final toLat = Rxn<double>();
  final toLng = Rxn<double>();
  final loadingLocation = true.obs;

  /// true = route origin uses GPS; false = user picked a FROM airport manually.
  bool _fromPinnedToAirport = false;

  /// User placed origin by tapping the search map.
  bool _fromIsMapPin = false;

  /// User placed destination by tapping the search map.
  bool _toIsMapPin = false;

  /// Active map pin mode (FROM or TO); null = not picking.
  final mapPinPickTarget = Rxn<MapPinPickTarget>();

  bool get pickingOnMap => mapPinPickTarget.value != null;

  bool get toIsMapPin => _toIsMapPin;

  /// FROM is the device position, not the airport coordinates from the list.
  bool get fromIsCurrentLocation =>
      !_fromPinnedToAirport &&
      !_fromIsMapPin &&
      fromLat.value != null &&
      fromLng.value != null;

  bool get fromIsMapPin => _fromIsMapPin;

  /// Great-circle distance in km when FROM and TO are set.
  double? get routeDistanceKm {
    final destCoords = _destinationCoords();
    final coords = _originCoords();
    if (coords == null || destCoords == null) return null;
    final (lat, lng) = coords;
    final (destLat, destLng) = destCoords;
    return FlightRouteUtils.distanceKm(lat, lng, destLat, destLng);
  }

  /// Estimated block time.
  Duration? get routeFlightDuration {
    final km = routeDistanceKm;
    if (km == null) return null;
    return FlightRouteUtils.estimatedFlightDuration(km);
  }

  bool get canContinueToSeats =>
      !loadingLocation.value && from.value != null && to.value != null;

  SearchRouteUxStep get routeUxStep {
    if (loadingLocation.value) return SearchRouteUxStep.findingOrigin;
    if (to.value == null) return SearchRouteUxStep.chooseDestination;
    if (from.value != null) return SearchRouteUxStep.routeReady;
    return SearchRouteUxStep.chooseDestination;
  }

  /// Primary CTA: open destination picker, or seats when the route is complete.
  void onPrimaryAction() {
    switch (routeUxStep) {
      case SearchRouteUxStep.findingOrigin:
        return;
      case SearchRouteUxStep.chooseDestination:
        pickAirport(isFrom: false);
      case SearchRouteUxStep.routeReady:
        if (travelMode.value == TravelMode.drive) {
          if (!canOpenRoadSeats) {
            if (!loadingRoadRoute.value) unawaited(_refreshRoadRoute());
            return;
          }
          unawaited(openRoadSeatSelection());
        } else {
          openSeatSelection();
        }
    }
  }

  String? get routeSummaryLabel {
    final origin = from.value;
    final dest = to.value;
    if (origin == null || dest == null) return null;
    return '${origin.code} → ${dest.code}';
  }

  // ── Map state (not reactive — map API drives its own rendering) ────────────
  MapboxMap? mapCtrl;
  List<List<double>> currentArc = [];
  CircleAnnotationManager? planeAnnotMgr;
  bool _mapSessionAlive = false;
  bool _styleLayersAdded = false;
  int _mapSetupGen = 0;
  int _locationResolveGen = 0;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  // Location puck setup runs after the map is ready (same as the former home tab).

  Future<void> _resolveFromNearestAirport() async {
    final gen = ++_locationResolveGen;
    loadingLocation.value = true;
    try {
      final pos = await _locationService.getCurrentPosition();
      _fromPinnedToAirport = false;
      _fromIsMapPin = false;
      mapPinPickTarget.value = null;
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

      if (gen != _locationResolveGen) return;

      if (from.value == null) {
        await _applyFallbackOrigin();
      }
    } finally {
      if (gen == _locationResolveGen) {
        loadingLocation.value = false;
      }
    }

    if (gen != _locationResolveGen) return;

    await _updateRoute();
    if (_styleLayersAdded && mapCtrl != null) {
      await _fitCamera(animate: false);
    }
  }

  /// เมื่อ GPS ปิด/ปฏิเสธ — ให้เลือกต้นทาง BKK แทนการค้างโหลด
  Future<void> _applyFallbackOrigin() async {
    final airport = await _airportRepo.findByIata('BKK');
    if (airport == null) return;
    _fromPinnedToAirport = true;
    from.value = airport;
    fromLat.value = null;
    fromLng.value = null;
  }

  /// Route origin — GPS / map pin use [fromLat]/[fromLng]; airport picker uses airport coords.
  (double lat, double lng)? _originCoords() {
    final airport = from.value;
    if (airport == null) return null;
    if ((fromIsCurrentLocation || fromIsMapPin) &&
        fromLat.value != null &&
        fromLng.value != null) {
      return (fromLat.value!, fromLng.value!);
    }
    return (airport.lat, airport.lng);
  }

  (double lat, double lng)? _destinationCoords() {
    final airport = to.value;
    if (airport == null) return null;
    if (_toIsMapPin && toLat.value != null && toLng.value != null) {
      return (toLat.value!, toLng.value!);
    }
    return (airport.lat, airport.lng);
  }

  void startMapPinPicker({required bool isFrom}) {
    final target =
        isFrom ? MapPinPickTarget.from : MapPinPickTarget.to;
    if (mapPinPickTarget.value == target) {
      cancelMapPinPicker();
      return;
    }
    mapPinPickTarget.value = target;
    HapticFeedback.selectionClick();
  }

  void cancelMapPinPicker() {
    mapPinPickTarget.value = null;
  }

  void onSearchMapTap(MapContentGestureContext context) {
    final target = mapPinPickTarget.value;
    if (target == null) return;
    final coords = context.point.coordinates;
    final lat = coords.lat.toDouble();
    final lng = coords.lng.toDouble();
    switch (target) {
      case MapPinPickTarget.from:
        unawaited(_applyMapPinOrigin(lat, lng));
      case MapPinPickTarget.to:
        unawaited(_applyMapPinDestination(lat, lng));
    }
  }

  Future<void> _applyMapPinOrigin(double lat, double lng) async {
    final gen = ++_locationResolveGen;
    loadingLocation.value = true;
    mapPinPickTarget.value = null;
    try {
      _fromPinnedToAirport = false;
      _fromIsMapPin = true;
      fromLat.value = lat;
      fromLng.value = lng;
      from.value = await _airportRepo.findNearestAirport(lat, lng);
      if (gen != _locationResolveGen) return;
      if (from.value == null) await _applyFallbackOrigin();
    } finally {
      if (gen == _locationResolveGen) loadingLocation.value = false;
    }
    if (gen != _locationResolveGen) return;
    await _updateRoute();
    if (_styleLayersAdded && mapCtrl != null) {
      await _fitCamera(animate: true);
    }
    HapticFeedback.lightImpact();
  }

  Future<void> _applyMapPinDestination(double lat, double lng) async {
    mapPinPickTarget.value = null;
    try {
      _toIsMapPin = true;
      toLat.value = lat;
      toLng.value = lng;
      to.value = await _airportRepo.findNearestAirport(lat, lng);
    } finally {}
    if (to.value == null) {
      _toIsMapPin = false;
      toLat.value = null;
      toLng.value = null;
      return;
    }
    await _updateRoute();
    if (_styleLayersAdded && mapCtrl != null) {
      await _fitCamera(animate: true);
    }
    HapticFeedback.lightImpact();
  }

  Future<void> useCurrentLocationForOrigin() async {
    mapPinPickTarget.value = null;
    _fromIsMapPin = false;
    await _resolveFromNearestAirport();
  }

  // ── Map lifecycle ──────────────────────────────────────────────────────────

  /// Native map view created — style layers wait for [onSearchMapStyleLoaded].
  Future<void> onMapCreated(MapboxMap map) async {
    _mapSetupGen++;
    mapCtrl = map;
    _mapSessionAlive = true;
    _styleLayersAdded = false;

    try {
      await map.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          pulsingColor: 0xFFF6A93B,
          locationPuck: LocationPuck(locationPuck2D: DefaultLocationPuck2D()),
        ),
      );
    } catch (_) {}
  }

  /// Style is ready — safe to call StyleManager.addStyleLayer (avoids channel-error).
  Future<void> onSearchMapStyleLoaded(StyleLoadedEventData _) async {
    await _setupSearchMapStyle();
  }

  /// Map unmounted (tab switch / widget dispose) — cancel in-flight style work.
  void onSearchMapUnmounted() {
    _mapSessionAlive = false;
    _styleLayersAdded = false;
    mapCtrl = null;
    planeAnnotMgr = null;
  }

  Future<void> _setupSearchMapStyle() async {
    final map = mapCtrl;
    if (map == null || !_mapSessionAlive || _styleLayersAdded) return;

    final gen = _mapSetupGen;
    _styleLayersAdded = true;

    try {
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

      if (!_mapSessionAlive || gen != _mapSetupGen) return;

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
    } catch (_) {
      if (gen == _mapSetupGen) _styleLayersAdded = false;
    }

    if (!_mapSessionAlive || gen != _mapSetupGen) return;

    await _syncRouteLayers();
    if (from.value != null) {
      await _fitCamera(animate: false);
    }
  }

  /// Fetches real road route from Mapbox Directions (or falls back to great-circle)
  Future<void> _refreshRoadRoute() async {
    final origin = _originCoords();
    final dest = to.value;
    if (origin == null || dest == null) {
      roadRouteCoords.clear();
      roadDistanceKm.value = null;
      roadDuration.value = null;
      loadingRoadRoute.value = false;
      await _syncRouteLayers();
      return;
    }

    final gen = ++_roadFetchGen;
    loadingRoadRoute.value = true;
    final (originLat, originLng) = origin;

    final destCoords = _destinationCoords();
    if (destCoords == null) return;
    final (destLat, destLng) = destCoords;

    final result = await _roadRouteRepo.fetchDrivingRoute(
      fromLat: originLat,
      fromLng: originLng,
      toLat: destLat,
      toLng: destLng,
    );

    if (gen != _roadFetchGen) return;

    try {
      if (result != null && result.coords.length >= 2) {
        roadRouteCoords.assignAll(result.coords);
        roadDistanceKm.value = result.distanceKm;
        // ใช้ระยะถนนจริง แต่เวลาโฟกัสคำนวณที่ 150 km/h
        roadDuration.value =
            _roadRouteRepo.estimateFocusDuration(result.distanceKm);
      } else {
        final km = routeDistanceKm ?? 0.0;
        roadRouteCoords.assignAll(_greatCircleArc(n: 80));
        roadDistanceKm.value = km;
        roadDuration.value = _roadRouteRepo.estimateFocusDuration(km);
      }
    } finally {
      if (gen == _roadFetchGen) loadingRoadRoute.value = false;
    }

    if (gen != _roadFetchGen) return;

    await _syncRouteLayers();
    if (to.value != null) await _fitCamera(animate: true);
  }

  List<List<double>> _activeRouteCoords() {
    if (travelMode.value == TravelMode.drive && roadRouteCoords.isNotEmpty) {
      return roadRouteCoords.toList();
    }
    return _greatCircleArc();
  }

  Future<void> _syncRouteLayers() async {
    final map = mapCtrl;
    if (map == null || !_mapSessionAlive || !_styleLayersAdded) return;
    currentArc = _activeRouteCoords();
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
    if (travelMode.value == TravelMode.drive && to.value != null) {
      await _refreshRoadRoute();
    } else {
      roadRouteCoords.clear();
      roadDistanceKm.value = null;
      roadDuration.value = null;
      await _syncRouteLayers();
      if (to.value != null) await _fitCamera(animate: true);
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
    } else if (travelMode.value == TravelMode.drive &&
        currentArc.length >= 2) {
      final bounds = _boundsForCoords(currentArc);
      opts = CameraOptions(
        center: Point(
          coordinates: Position(bounds.midLng, bounds.midLat),
        ),
        zoom: bounds.zoom,
        pitch: 28.0,
        bearing: 0.0,
      );
    } else {
      final destCoords = _destinationCoords();
      if (destCoords == null) return;
      final (destLat, destLng) = destCoords;
      final midLat = (originLat + destLat) / 2;
      final midLng = (originLng + destLng) / 2;
      final span = math.max(
        (originLat - destLat).abs(),
        (originLng - destLng).abs(),
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
          'code': fromIsMapPin
              ? 'PIN'
              : (fromIsCurrentLocation ? 'GPS' : origin.code),
          'kind': 'from',
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [originLng, originLat],
        },
      },
    ];
    if (dest != null) {
      final destCoords = _destinationCoords();
      if (destCoords != null) {
        final (destLat, destLng) = destCoords;
        features.add({
          'type': 'Feature',
          'properties': {
            'code': toIsMapPin ? 'PIN' : dest.code,
            'kind': 'to',
          },
          'geometry': {
            'type': 'Point',
            'coordinates': [destLng, destLat],
          },
        });
      }
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

  ({double minLat, double maxLat, double minLng, double maxLng, double midLat,
      double midLng, double zoom}) _boundsForCoords(List<List<double>> coords) {
    var minLat = 90.0;
    var maxLat = -90.0;
    var minLng = 180.0;
    var maxLng = -180.0;
    for (final p in coords) {
      final lng = p[0];
      final lat = p[1];
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }
    final midLat = (minLat + maxLat) / 2;
    final midLng = (minLng + maxLng) / 2;
    final span = math.max((maxLat - minLat).abs(), (maxLng - minLng).abs());
    final zoom = span < 0.5
        ? 11.0
        : span < 1.5
        ? 9.5
        : span < 4
        ? 8.0
        : span < 10
        ? 6.5
        : span < 25
        ? 5.0
        : 4.0;
    return (
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      midLat: midLat,
      midLng: midLng,
      zoom: zoom,
    );
  }

  List<List<double>> _greatCircleArc({int n = 60}) {
    final coords = _originCoords();
    final destCoords = _destinationCoords();
    if (coords == null || destCoords == null) return [];

    final (originLat, originLng) = coords;
    final (destLat, destLng) = destCoords;
    final r1 = originLat * math.pi / 180;
    final o1 = originLng * math.pi / 180;
    final r2 = destLat * math.pi / 180;
    final o2 = destLng * math.pi / 180;
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
        [destLng, destLat],
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
    _fromIsMapPin = false;
    _toIsMapPin = false;
    mapPinPickTarget.value = null;
    fromLat.value = null;
    fromLng.value = null;
    toLat.value = null;
    toLng.value = null;
    from.value = dest;
    to.value = origin;
    unawaited(_updateRoute());
  }

  Future<void> pickAirport({required bool isFrom}) async {
    if (isFrom) {
      _locationResolveGen++;
      loadingLocation.value = false;
      mapPinPickTarget.value = null;
      _fromIsMapPin = false;
    } else {
      mapPinPickTarget.value = null;
      _toIsMapPin = false;
      toLat.value = null;
      toLng.value = null;
    }
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
      _toIsMapPin = false;
      toLat.value = null;
      toLng.value = null;
      to.value = result;
    }
    await _updateRoute();
  }

  void openSeatSelection() {
    if (!canContinueToSeats) return;
    final origin = from.value!;
    final dest = to.value!;
    HapticFeedback.mediumImpact();
    final (originLat, originLng) = _originCoords()!;
    final (destLat, destLng) = _destinationCoords()!;
    Get.to(
      () => SeatSelectionView(
        fromCode: origin.code,
        fromCity: origin.city,
        toCode: dest.code,
        toCity: dest.city,
        distanceKm: routeDistanceKm,
        flightDuration: routeFlightDuration,
        fromLat: originLat,
        fromLng: originLng,
        toLat: destLat,
        toLng: destLng,
      ),
    );
  }

  Future<void> openRoadSeatSelection() async {
    if (!canContinueToSeats) return;
    if (!canOpenRoadSeats) {
      await _refreshRoadRoute();
      if (!canOpenRoadSeats) return;
    }

    final origin = from.value!;
    final dest = to.value!;
    HapticFeedback.mediumImpact();
    final (originLat, originLng) = _originCoords()!;
    final (destLat, destLng) = _destinationCoords()!;
    final coords = List<List<double>>.from(roadRouteCoords);
    final km = roadDistanceKm.value ?? routeDistanceKm ?? 0.0;
    final dur =
        roadDuration.value ?? _roadRouteRepo.estimateFocusDuration(km);

    Get.to(
      () => RoadSeatView(
        fromCity: origin.city,
        fromCountry: origin.country,
        toCity: dest.city,
        toCountry: dest.country,
        fromLat: originLat,
        fromLng: originLng,
        toLat: destLat,
        toLng: destLng,
        distanceKm: km,
        duration: dur,
        routeCoords: coords,
      ),
    );
  }
}
