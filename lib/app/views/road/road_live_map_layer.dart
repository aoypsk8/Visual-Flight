import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../models/road_trip_session.dart';
import '../../utils/app_colors.dart';
import '../../utils/live_map_style_options.dart';
import '../../widgets/map/deferred_map_host.dart';
import '../../widgets/map/live_map_chrome.dart';

/// Live road map — same controls as [LiveFlightMapLayer] (style, zoom, follow).
class RoadLiveMapLayer extends StatefulWidget {
  const RoadLiveMapLayer({
    super.key,
    required this.session,
    this.uiHidden = false,
    /// Bottom inset so map controls don't overlap the HUD
    this.controlsBottomInset = 228,
  });

  final RoadTripSession session;
  final bool uiHidden;
  final double controlsBottomInset;

  @override
  State<RoadLiveMapLayer> createState() => _RoadLiveMapLayerState();
}

class _RoadLiveMapLayerState extends State<RoadLiveMapLayer>
    with TickerProviderStateMixin {
  static const double _progressLerp = 0.24;
  static const double _bearingLerp = 0.18;
  static const int _carGeoMs = 32;
  static const int _flownLineMs = 48;
  /// ดันแผนที่ขึ้นเล็กน้อยให้จุดบนเส้นทางตรงกับไอคอนรถกลางจอ (pitch 3D)
  static const double _followPaddingFactor = 0.18;
  static const double _minZoom = 2.5;
  static const double _maxZoom = 19.0;
  static const double _zoomStep = 0.85;
  static const double _buildingVisibleZoom = 14.2;

  MapboxMap? _map;
  CircleAnnotationManager? _haloMgr;
  CircleAnnotation? _haloAnn;
  CircleAnnotationManager? _carMgr;
  CircleAnnotation? _carAnn;

  bool _ready = false;
  bool _styleLayersAdded = false;
  bool _mapHostMounted = false;
  bool _mapSessionAlive = false;
  bool _pendingStyleReload = false;
  bool _manualOverride = false;
  bool _map3dEnabled = true;
  bool _userAdjustingZoom = false;

  double? _routeZoom;
  double? _followZoom;
  double _displayBearing = 0;
  double _displayProgress = 0;

  LiveMapStyleOption _mapStyle =
      LiveMapStyleOptions.byId(LiveMapStyleOptions.defaultId);

  late final AnimationController _pulseCtrl;
  final ValueNotifier<int> _percentNotifier = ValueNotifier(0);
  Ticker? _trackTicker;
  Timer? _zoomGestureEndTimer;

  double _trackProgress = 0;
  int _trackFrameGen = 0;
  int _lastFlownMs = 0;
  int _lastCarGeoMs = 0;
  int _lastPercentMs = 0;
  DateTime _ignoreUserGesturesUntil = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _canTouchMap =>
      mounted && _mapSessionAlive && _mapHostMounted && _map != null;

  bool get _isFollowing => !_manualOverride;

  List<List<double>> get _routeCoords {
    final c = widget.session.routeCoords;
    if (c.length >= 2) return c;
    final s = widget.session;
    return [
      [s.fromLng, s.fromLat],
      [s.toLng, s.toLat],
    ];
  }

  void _markProgrammaticCamera([
    Duration grace = const Duration(milliseconds: 450),
  ]) {
    _ignoreUserGesturesUntil = DateTime.now().add(grace);
  }

  bool get _acceptUserGestures =>
      _ready && DateTime.now().isAfter(_ignoreUserGesturesUntil);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _displayProgress = _progressNow();
    _trackProgress = _displayProgress;
    _percentNotifier.value = (_trackProgress * 100).round();
  }

  void _resetDisplayProgress() {
    _displayProgress = _progressNow();
    _trackProgress = _displayProgress;
  }

  void _advanceDisplayProgress(Duration elapsed) {
    final target = _progressNow();
    final dt = (elapsed.inMicroseconds / 1e6).clamp(0.001, 0.05);
    final step = 1 - math.pow(1 - _progressLerp, dt * 60.0);
    _displayProgress += (target - _displayProgress) * step;
    if ((target - _displayProgress).abs() < 0.00005) {
      _displayProgress = target;
    }
  }

  Future<void> _safeCircleUpdate(CircleAnnotation annotation) async {
    final mgr = _haloMgr;
    if (!_canTouchMap || mgr == null) return;
    try {
      await mgr.update(annotation);
    } catch (_) {}
  }

  Future<void> _safeCarUpdate(CircleAnnotation annotation) async {
    final mgr = _carMgr;
    if (!_canTouchMap || mgr == null) return;
    try {
      await mgr.update(annotation);
    } catch (_) {}
  }

  bool _shouldUpdateFlownLine(bool following) {
    if (following) return true;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFlownMs < _flownLineMs) return false;
    _lastFlownMs = now;
    return true;
  }

  Future<void> _syncCarGlowVisibility(bool following) async {
    final map = _map;
    if (map == null || !_canTouchMap) return;
    try {
      await map.style.setStyleLayerProperty(
        'road-car-glow',
        'circle-opacity',
        following ? 0.0 : 0.30,
      );
    } catch (_) {}
  }

  bool _shouldUpdateCarGeo() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastCarGeoMs < _carGeoMs) return false;
    _lastCarGeoMs = now;
    return true;
  }

  @override
  void dispose() {
    _mapSessionAlive = false;
    _trackTicker?.dispose();
    _zoomGestureEndTimer?.cancel();
    _pulseCtrl.dispose();
    _percentNotifier.dispose();
    _map = null;
    _haloMgr = null;
    _haloAnn = null;
    _carMgr = null;
    _carAnn = null;
    super.dispose();
  }

  double _progressNow() => widget.session.progressAt(DateTime.now());

  List<double> _posAt(double progress) {
    final (lat, lng) = widget.session.positionAt(progress);
    return [lng, lat];
  }

  double _bearingAt(double progress) =>
      widget.session.bearingAt(progress);

  static double _bearingDelta(double from, double to) {
    var d = to - from;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d;
  }

  void _lerpBearing(double target) {
    final d = _bearingDelta(_displayBearing, target);
    _displayBearing = (_displayBearing + d * _bearingLerp) % 360;
  }

  void _maybeUpdatePercent(double p) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPercentMs < 450) return;
    _lastPercentMs = now;
    final pct = (p * 100).round();
    if (_percentNotifier.value != pct) _percentNotifier.value = pct;
  }

  void _onMapHostMountChanged(bool mounted) {
    if (!mounted) {
      _mapHostMounted = false;
      _mapSessionAlive = false;
      _trackTicker?.stop();
      _ready = false;
      _map = null;
      _haloMgr = null;
      _haloAnn = null;
      _carMgr = null;
      _carAnn = null;
      return;
    }
    _mapHostMounted = true;
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    _styleLayersAdded = false;
    _ready = false;
    _mapSessionAlive = true;
    try {
      await map.gestures.updateSettings(GesturesSettings(
        pinchToZoomEnabled: true,
        scrollEnabled: true,
        pitchEnabled: true,
        rotateEnabled: true,
        doubleTapToZoomInEnabled: true,
        doubleTouchToZoomOutEnabled: true,
        quickZoomEnabled: true,
        pinchToZoomDecelerationEnabled: true,
      ));
    } catch (_) {}
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    if (_map == null || !_mapSessionAlive) return;
    if (_styleLayersAdded) return;
    final preserve = _pendingStyleReload;
    _pendingStyleReload = false;
    await _setupLayers(preserveProgress: preserve);
  }

  Future<void> _setupLayers({bool preserveProgress = false}) async {
    final map = _map;
    if (map == null || !_mapSessionAlive) return;
    _styleLayersAdded = true;

    final coords = _routeCoords;
    final p = preserveProgress
        ? widget.session.progressAt(DateTime.now()).clamp(0.0, 1.0)
        : 0.0;

    if (coords.length >= 2) {
      await _safeAddSource(
        map,
        GeoJsonSource(id: 'road-route-full', data: _lineGeoJson(coords)),
      );
      await _safeAddLayer(map, LineLayer(
        id: 'road-route-base-casing',
        sourceId: 'road-route-full',
        lineColor: const Color(0xFF0A0B0D).toARGB32(),
        lineWidth: 5.0,
        lineOpacity: 0.62,
        lineDasharray: [2.0, 2.5],
        lineCap: LineCap.ROUND,
      ));
      await _safeAddLayer(map, LineLayer(
        id: 'road-route-base',
        sourceId: 'road-route-full',
        lineColor: AppColors.amber2.toARGB32(),
        lineWidth: 3.0,
        lineOpacity: 0.92,
        lineDasharray: [2.0, 2.5],
        lineCap: LineCap.ROUND,
      ));

      final flown = widget.session.routeSliceAt(p);
      await _safeAddSource(
        map,
        GeoJsonSource(
          id: 'road-route-flown',
          data: _lineGeoJson(flown.isNotEmpty ? flown : [coords.first]),
        ),
      );
      await _safeAddLayer(map, LineLayer(
        id: 'road-route-amber',
        sourceId: 'road-route-flown',
        lineColor: AppColors.amber.toARGB32(),
        lineWidth: 5.0,
        lineOpacity: 0.95,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
      ));
    }

    await _safeAddSource(
      map,
      GeoJsonSource(id: 'road-endpoints', data: _endpointsGeoJson()),
    );
    await _safeAddLayer(map, CircleLayer(
      id: 'road-from-dot',
      sourceId: 'road-endpoints',
      filter: ['==', ['get', 'kind'], 'from'],
      circleRadius: 8,
      circleColor: AppColors.amber2.toARGB32(),
      circleStrokeWidth: 2.5,
      circleStrokeColor: const Color(0xFF0A0B0D).toARGB32(),
    ));
    await _safeAddLayer(map, CircleLayer(
      id: 'road-to-dot',
      sourceId: 'road-endpoints',
      filter: ['==', ['get', 'kind'], 'to'],
      circleRadius: 8,
      circleColor: AppColors.amber.toARGB32(),
      circleStrokeWidth: 2.5,
      circleStrokeColor: const Color(0xFF0A0B0D).toARGB32(),
    ));

    final startPos = _posAt(p);
    await _safeAddSource(
      map,
      GeoJsonSource(id: 'road-car', data: _pointGeoJson(startPos)),
    );
    await _safeAddLayer(map, CircleLayer(
      id: 'road-car-glow',
      sourceId: 'road-car',
      circleRadius: 26,
      circleColor: AppColors.amber.toARGB32(),
      circleOpacity: 0.30,
      circleBlur: 0.85,
    ));

    _haloMgr = await map.annotations.createCircleAnnotationManager();
    _haloAnn = await _haloMgr!.create(CircleAnnotationOptions(
      geometry: Point(coordinates: Position(startPos[0], startPos[1])),
      circleRadius: 22,
      circleColor: AppColors.amber.toARGB32(),
      circleOpacity: 0.18,
      circleBlur: 0.5,
    ));

    _carMgr = await map.annotations.createCircleAnnotationManager();
    _carAnn = await _carMgr!.create(CircleAnnotationOptions(
      geometry: Point(coordinates: Position(startPos[0], startPos[1])),
      circleRadius: 10,
      circleColor: AppColors.amber.toARGB32(),
      circleStrokeWidth: 3,
      circleStrokeColor: Colors.white.toARGB32(),
      circleOpacity: _isFollowing ? 0 : 0.95,
    ));

    if (_map3dEnabled) {
      if (_mapStyle.supportsStandard3dConfig) {
        await _setMapbox3dBuildings(true);
      }
      await _enableMapboxTerrain();
    }

    _routeZoom = _computeRouteZoom();
    _resetDisplayProgress();
    _displayBearing = _bearingAt(_displayProgress);
    _markProgrammaticCamera(const Duration(milliseconds: 1600));
    await _fitRouteOverview();
    _percentNotifier.value = (_progressNow() * 100).round();
    setState(() => _ready = true);
    await Future.delayed(const Duration(milliseconds: 350));
    await _syncCarGlowVisibility(true);
    await _resumeTracking();
    _startTracking();
  }

  void _startTracking() {
    _trackTicker?.dispose();
    _trackTicker = createTicker(_onTrackTick)..start();
  }

  void _onTrackTick(Duration elapsed) {
    if (!_canTouchMap || !_ready) return;
    _advanceDisplayProgress(elapsed);
    final p = _displayProgress;
    _lerpBearing(_bearingAt(p));
    _trackProgress = p;
    final gen = ++_trackFrameGen;
    final following = _isFollowing;
    _applyTrackFrame(
      gen,
      p,
      following: following,
      updateFlown: _shouldUpdateFlownLine(following),
    );
    _maybeUpdatePercent(_progressNow());
  }

  void _applyTrackFrame(
    int gen,
    double p, {
    required bool following,
    required bool updateFlown,
  }) {
    if (!_canTouchMap || gen != _trackFrameGen) return;
    final map = _map;
    if (map == null) return;

    final progress = p.clamp(0.0, 1.0);
    final pos = _posAt(progress);
    final pt = Point(coordinates: Position(pos[0], pos[1]));

    if (following) {
      final followZoom = _followZoomLevel();
      _markProgrammaticCamera(const Duration(milliseconds: 80));
      final camOpts = CameraOptions(
        center: pt,
        pitch: _activeFollowPitch(followZoom),
        bearing: _displayBearing,
        padding: MbxEdgeInsets(
          top: 0,
          left: 0,
          bottom: widget.controlsBottomInset * _followPaddingFactor,
          right: 0,
        ),
      );
      if (!_userAdjustingZoom) camOpts.zoom = followZoom;
      unawaited(map.setCamera(camOpts).catchError((_) {}));
    } else {
      if (_shouldUpdateCarGeo()) {
        unawaited(
          map.style
              .setStyleSourceProperty('road-car', 'data', _pointGeoJson(pos))
              .catchError((_) {}),
        );
      }
      final halo = _haloAnn;
      if (halo != null) {
        halo.geometry = pt;
        halo.circleRadius = 18 + 8 * _pulseCtrl.value;
        halo.circleOpacity = 0.20 - 0.12 * _pulseCtrl.value;
        unawaited(_safeCircleUpdate(halo));
      }
      final car = _carAnn;
      if (car != null) {
        car.geometry = pt;
        car.circleOpacity = 0.95;
        unawaited(_safeCarUpdate(car));
      }
    }

    if (updateFlown) {
      unawaited(_updateFlownRoute(map, progress));
    }
  }

  Future<void> _updateFlownRoute(MapboxMap map, double progress) async {
    final slice = widget.session.routeSliceAt(progress);
    if (slice.length < 2) return;
    try {
      await map.style.setStyleSourceProperty(
        'road-route-flown',
        'data',
        _lineGeoJson(slice),
      );
    } catch (_) {}
  }

  double _routeLatLngSpan() {
    final s = widget.session;
    return math.max(
      (s.fromLat - s.toLat).abs(),
      (s.fromLng - s.toLng).abs(),
    );
  }

  double _computeRouteZoom() {
    final span = _routeLatLngSpan();
    if (span < 0.5) return 13.5;
    if (span < 2) return 12.0;
    if (span < 5) return 10.5;
    if (span < 12) return 9.0;
    return 7.5;
  }

  double _defaultFollowZoom() {
    final routeZ = _routeZoom ?? 10.0;
    var z = (routeZ + 2.2).clamp(_minZoom, _maxZoom);
    if (_map3dEnabled && _routeLatLngSpan() < 4) {
      z = math.max(z, _buildingVisibleZoom);
    }
    return z;
  }

  double _followZoomLevel() =>
      (_followZoom ?? _defaultFollowZoom()).clamp(_minZoom, _maxZoom);

  double _computeFollowPitch([double? zoom]) {
    final z = zoom ?? _followZoomLevel();
    if (!_map3dEnabled) return 0;
    // Satellite + pitch สูงมักทำให้ tile แตกบน simulator — จำกัดมุม
    final isSatellite = _mapStyle.id == 'satellite_3d';
    var pitch = z >= _buildingVisibleZoom
        ? 62.0
        : z <= 7
        ? 25.0
        : 48.0;
    if (isSatellite) pitch = math.min(pitch, 50.0);
    return pitch;
  }

  double _activeFollowPitch([double? zoom]) => _computeFollowPitch(zoom);

  Future<void> _setMapbox3dBuildings(bool enabled) async {
    if (!_mapStyle.supportsStandard3dConfig) return;
    final map = _map;
    if (map == null || !_canTouchMap) return;
    final configs = <String, Object>{
      'show3dObjects': enabled,
      'show3dBuildings': enabled,
      'show3dLandmarks': enabled,
    };
    try {
      await map.style.setStyleImportConfigProperties('basemap', configs);
    } catch (_) {}
  }

  Future<void> _enableMapboxTerrain() async {
    final map = _map;
    if (map == null || !_canTouchMap) return;
    try {
      await map.style.setStyleTerrain(
        json.encode({'source': 'mapbox-raster-dem', 'exaggeration': 1.2}),
      );
    } catch (_) {}
  }

  Future<void> _disableMapboxTerrain() async {
    final map = _map;
    if (map == null || !_canTouchMap) return;
    try {
      await map.style.setStyleTerrainProperty('exaggeration', 0);
    } catch (_) {}
  }

  Future<void> _syncMap3dMode() async {
    if (_map3dEnabled) {
      if (_mapStyle.supportsStandard3dConfig) {
        await _setMapbox3dBuildings(true);
      }
      await _enableMapboxTerrain();
    } else {
      if (_mapStyle.supportsStandard3dConfig) {
        await _setMapbox3dBuildings(false);
      }
      await _disableMapboxTerrain();
    }
    if (_isFollowing) {
      _applyTrackFrame(
        ++_trackFrameGen,
        _displayProgress,
        following: true,
        updateFlown: true,
      );
    }
    unawaited(_syncCarGlowVisibility(_isFollowing));
  }

  Future<void> _reloadMapStyle() async {
    final map = _map;
    if (map == null || !_mapSessionAlive) return;
    _pendingStyleReload = true;
    _styleLayersAdded = false;
    _haloMgr = null;
    _haloAnn = null;
    _carMgr = null;
    _carAnn = null;
    if (mounted) setState(() => _ready = false);
    try {
      await map.loadStyleURI(_mapStyle.styleUri);
    } catch (_) {
      _pendingStyleReload = false;
      if (mounted) setState(() => _ready = true);
    }
  }

  void _selectMapStyle(LiveMapStyleOption option) {
    if (option.id == _mapStyle.id) return;
    HapticFeedback.selectionClick();
    setState(() => _mapStyle = option);
    unawaited(_reloadMapStyle());
  }

  Future<void> _toggleMap3d() async {
    HapticFeedback.selectionClick();
    setState(() {
      _map3dEnabled = !_map3dEnabled;
      if (_map3dEnabled) _followZoom = null;
    });
    await _syncMap3dMode();
    if (mounted) setState(() {});
  }

  List<Point> _routeBoundsPoints() {
    final pts = <Point>[];
    for (final c in _routeCoords) {
      pts.add(Point(coordinates: Position(c[0], c[1])));
    }
    return pts;
  }

  Future<void> _fitRouteOverview() async {
    final map = _map;
    if (map == null) return;
    _markProgrammaticCamera(const Duration(milliseconds: 1600));
    final coords = _routeBoundsPoints();
    if (coords.length < 2) return;
    try {
      var cam = await map.cameraForCoordinatesPadding(
        coords,
        CameraOptions(bearing: 0, pitch: 0),
        MbxEdgeInsets(top: 96, left: 40, bottom: 280, right: 88),
        null,
        null,
      );
      final z = cam.zoom;
      if (z != null) {
        cam = CameraOptions(
          center: cam.center,
          zoom: (z - 0.5).clamp(_minZoom, _maxZoom),
          bearing: 0,
          pitch: 0,
        );
      }
      await map.flyTo(cam, MapAnimationOptions(duration: 1100));
    } catch (_) {}
  }

  Future<void> _showRouteOverview() async {
    HapticFeedback.selectionClick();
    setState(() => _manualOverride = true);
    await _fitRouteOverview();
    if (mounted) setState(() {});
  }

  void _enterExploreMode() {
    if (_manualOverride) return;
    HapticFeedback.selectionClick();
    setState(() => _manualOverride = true);
    final car = _carAnn;
    if (car != null) {
      car.circleOpacity = 0.95;
      unawaited(_carMgr?.update(car));
    }
    unawaited(_syncCarGlowVisibility(false));
  }

  void _onUserMapGesture() {
    if (!_acceptUserGestures || _manualOverride) return;
    setState(() => _manualOverride = true);
  }

  void _onPinchOrZoomGesture() {
    if (!_acceptUserGestures) return;
    _userAdjustingZoom = true;
    _zoomGestureEndTimer?.cancel();
    _zoomGestureEndTimer = Timer(const Duration(milliseconds: 450), () {
      _userAdjustingZoom = false;
      unawaited(_captureFollowZoomFromCamera());
    });
    if (_isFollowing) return;
    if (!_manualOverride) _onUserMapGesture();
  }

  Future<void> _captureFollowZoomFromCamera() async {
    final map = _map;
    if (map == null || !_isFollowing) return;
    try {
      final cam = await map.getCameraState();
      _followZoom = cam.zoom.clamp(_minZoom, _maxZoom);
    } catch (_) {}
  }

  Future<void> _zoomBy(double delta) async {
    final map = _map;
    if (map == null) return;
    _markProgrammaticCamera(const Duration(milliseconds: 400));
    final cam = await map.getCameraState();
    final current = _isFollowing ? _followZoomLevel() : cam.zoom;
    final next = (current + delta * _zoomStep).clamp(_minZoom, _maxZoom);
    if (_isFollowing) {
      _followZoom = next;
    } else {
      _enterExploreMode();
    }
    await map.flyTo(
      CameraOptions(
        zoom: next,
        pitch: _isFollowing ? _activeFollowPitch(next) : cam.pitch,
        bearing: _isFollowing ? _displayBearing : cam.bearing,
      ),
      MapAnimationOptions(duration: 220),
    );
  }

  Future<void> _resumeTracking() async {
    setState(() {
      _manualOverride = false;
      _followZoom = null;
    });
    _resetDisplayProgress();
    _displayBearing = _bearingAt(_displayProgress);
    unawaited(_syncCarGlowVisibility(true));
    final map = _map;
    if (map != null) {
      _markProgrammaticCamera(const Duration(milliseconds: 600));
      final pos = _posAt(_displayProgress);
      final z = _followZoomLevel();
      try {
        await map.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(pos[0], pos[1])),
            zoom: z,
            pitch: _activeFollowPitch(z),
            bearing: _displayBearing,
            padding: MbxEdgeInsets(
              top: 0,
              left: 0,
              bottom: widget.controlsBottomInset * _followPaddingFactor,
              right: 0,
            ),
          ),
          MapAnimationOptions(duration: 480),
        );
      } catch (_) {}
    }
    _applyTrackFrame(
      ++_trackFrameGen,
      _displayProgress,
      following: true,
      updateFlown: true,
    );
    if (mounted) setState(() {});
  }

  Future<void> _safeAddSource(MapboxMap map, Source source) async {
    try {
      await map.style.addSource(source);
    } catch (_) {}
  }

  Future<void> _safeAddLayer(MapboxMap map, Layer layer) async {
    try {
      await map.style.addLayer(layer);
    } catch (_) {}
  }

  String _lineGeoJson(List<List<double>> coords) => jsonEncode({
        'type': 'Feature',
        'geometry': {'type': 'LineString', 'coordinates': coords},
        'properties': {},
      });

  String _pointGeoJson(List<double> pos) => jsonEncode({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': pos,
        },
        'properties': {},
      });

  String _endpointsGeoJson() {
    final s = widget.session;
    return jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [s.fromLng, s.fromLat],
          },
          'properties': {'kind': 'from', 'label': s.fromCity},
        },
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [s.toLng, s.toLat],
          },
          'properties': {'kind': 'to', 'label': s.toCity},
        },
      ],
    });
  }

  @override
  Widget build(BuildContext context) {
    final isFollowing = _isFollowing;

    return DeferredMapHost(
      immediate: true,
      placeholderColor: const Color(0xFF0C0D10),
      onMountChanged: _onMapHostMountChanged,
      builder: (context) {
        return Stack(
              fit: StackFit.expand,
              children: [
                SizedBox.expand(
                  child: MapWidget(
                    key: ValueKey('road-live-map-${_mapStyle.id}'),
                    styleUri: _mapStyle.styleUri,
                    onMapCreated: _onMapCreated,
                    onStyleLoadedListener: _onStyleLoaded,
                    onScrollListener: (_) => _onUserMapGesture(),
                    onZoomListener: (_) => _onPinchOrZoomGesture(),
                  ),
                ),
                if (!_ready)
                  const Positioned.fill(
                    child: LiveMapLoadingOverlay(
                      message: 'Loading drive map…',
                    ),
                  ),
                if (_ready && isFollowing)
                  IgnorePointer(
                    child: Align(
                      alignment: const Alignment(0, -0.06),
                      child: AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, __) => LiveMapVehicleOverlay(
                          pulse: _pulseCtrl.value,
                          icon: Icons.directions_car_rounded,
                        ),
                      ),
                    ),
                  ),
                if (_ready && !widget.uiHidden)
                  Positioned(
                    right: 14,
                    bottom: widget.controlsBottomInset,
                    child: LiveMapViewControls(
                      isFollowing: isFollowing,
                      map3dEnabled: _map3dEnabled,
                      followTooltip: 'Follow car',
                      exploreTooltip: 'Explore map',
                      onPickStyle: () => showLiveMapStylePicker(
                        context,
                        selectedId: _mapStyle.id,
                        subtitle: 'Pick your drive view',
                        onSelected: _selectMapStyle,
                      ),
                      onZoomIn: () => unawaited(_zoomBy(1)),
                      onZoomOut: () => unawaited(_zoomBy(-1)),
                      onExplore: _enterExploreMode,
                      onRouteOverview: () => unawaited(_showRouteOverview()),
                      onToggle3d: () => unawaited(_toggleMap3d()),
                      onFollow: () {
                        HapticFeedback.mediumImpact();
                        unawaited(_resumeTracking());
                      },
                    ),
                  ),
              ],
            );
      },
    );
  }
}
