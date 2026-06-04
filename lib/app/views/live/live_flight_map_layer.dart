import 'dart:async';
import 'dart:convert';
import 'dart:math' show max, pi;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../config/api_urls.dart';
import '../../widgets/map/deferred_map_host.dart';
import '../../utils/app_colors.dart';
import '../../utils/flight_route_arc.dart';
import '../../utils/live_map_style_options.dart';
import '../../utils/solar_terminator.dart';

class LiveFlightMapLayer extends StatefulWidget {
  const LiveFlightMapLayer({
    super.key,
    required this.fromCode,
    required this.toCode,
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
    required this.startedAt,
    required this.totalSeconds,
    required this.progress,
    this.followCamera = true,
    this.uiHidden = false,
  });

  final String fromCode;
  final String toCode;
  final double fromLat;
  final double fromLng;
  final double toLat;
  final double toLng;
  final DateTime startedAt;
  final int totalSeconds;
  final double progress;
  final bool followCamera;
  final bool uiHidden;

  @override
  State<LiveFlightMapLayer> createState() => _LiveFlightMapLayerState();
}

class _LiveFlightMapLayerState extends State<LiveFlightMapLayer>
    with TickerProviderStateMixin {
  /// ลื่นกล้อง / ทิศทาง — ค่าต่ำ = นุ่มขึ้น
  static const double _camLerp = 0.26;
  static const double _bearingLerp = 0.14;
  static const int _aircraftGeoMs = 40;
  static const double _planeTextRotateOffset = -45;
  static const double _minZoom = 2.5;
  static const double _maxZoom = 19.0;
  static const double _zoomStep = 0.85;
  /// ซูมขั้นต่ำที่มักเห็นตึก 3D บน Mapbox Standard
  static const double _buildingVisibleZoom = 14.2;

  MapboxMap? _map;
  CircleAnnotationManager? _haloMgr;
  CircleAnnotation? _haloAnn;
  PointAnnotationManager? _planeMgr;
  PointAnnotation? _planeAnn;
  List<List<double>> _arc = [];
  bool _ready = false;
  bool _styleLayersAdded = false;
  double? _routeZoom;
  bool _manualOverride = false;
  late final AnimationController _pulseCtrl;
  final ValueNotifier<int> _percentNotifier = ValueNotifier(0);
  /// Zoom ที่ผู้ใช้เลือกขณะ follow (pinch / ปุ่ม +/-)
  double? _followZoom;
  bool _userAdjustingZoom = false;
  Timer? _zoomGestureEndTimer;
  /// โหมด 3D — terrain + pitch ตอนติดตามเที่ยวบิน
  bool _map3dEnabled = true;
  LiveMapStyleOption _mapStyle =
      LiveMapStyleOptions.byId(LiveMapStyleOptions.defaultId);

  Ticker? _trackTicker;
  double _trackProgress = 0;
  double _displayBearing = 0;
  double _smoothLng = 0;
  double _smoothLat = 0;
  bool _smoothCamInit = false;
  int _lastFlownLineMs = 0;
  int _lastAircraftGeoMs = 0;
  int _lastNightUpdateMs = 0;
  int _lastPercentMs = 0;
  DateTime _ignoreUserGesturesUntil = DateTime.fromMillisecondsSinceEpoch(0);
  bool _mapHostMounted = false;
  bool _mapSessionAlive = false;
  bool _pendingStyleReload = false;

  bool get _canTouchMap =>
      mounted && _mapSessionAlive && _mapHostMounted && _map != null;

  void _markProgrammaticCamera([Duration grace = const Duration(milliseconds: 450)]) {
    _ignoreUserGesturesUntil = DateTime.now().add(grace);
  }

  bool get _acceptUserGestures =>
      _ready && DateTime.now().isAfter(_ignoreUserGesturesUntil);

  @override
  void initState() {
    super.initState();
    _trackProgress = _progressNow();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _mapSessionAlive = false;
    _trackTicker?.dispose();
    _trackTicker = null;
    _zoomGestureEndTimer?.cancel();
    _pulseCtrl.dispose();
    _percentNotifier.dispose();
    _map = null;
    _haloMgr = null;
    _haloAnn = null;
    _planeMgr = null;
    _planeAnn = null;
    super.dispose();
  }

  void _onMapHostMountChanged(bool mounted) {
    if (!mounted) {
      _pauseMapSession();
      return;
    }
    _mapHostMounted = true;
  }

  /// หยุดอัปเดต map/annotation เมื่อ native MapView ถูกถอด
  void _pauseMapSession() {
    _mapHostMounted = false;
    _mapSessionAlive = false;
    _trackTicker?.stop();
    _ready = false;
    _map = null;
    _haloMgr = null;
    _haloAnn = null;
    _planeMgr = null;
    _planeAnn = null;
  }

  Future<void> _safeCircleUpdate(CircleAnnotation annotation) async {
    final mgr = _haloMgr;
    if (!_canTouchMap || mgr == null) return;
    try {
      await mgr.update(annotation);
    } catch (_) {}
  }

  Future<void> _safePointUpdate(PointAnnotation annotation) async {
    final mgr = _planeMgr;
    if (!_canTouchMap || mgr == null) return;
    try {
      await mgr.update(annotation);
    } catch (_) {}
  }

  void _resetSmoothCamera() {
    _smoothCamInit = false;
  }

  List<double> _smoothPosition(List<double> pos) {
    if (!_smoothCamInit) {
      _smoothLng = pos[0];
      _smoothLat = pos[1];
      _smoothCamInit = true;
      return pos;
    }
    _smoothLng += (pos[0] - _smoothLng) * _camLerp;
    _smoothLat += (pos[1] - _smoothLat) * _camLerp;
    return [_smoothLng, _smoothLat];
  }

  bool get _isFollowing => widget.followCamera && !_manualOverride;

  /// Progress from wall clock (smooth sub-second movement).
  double _progressNow() {
    if (widget.totalSeconds <= 0) return 1.0;
    final elapsedMs =
        DateTime.now().difference(widget.startedAt).inMilliseconds;
    return (elapsedMs / (widget.totalSeconds * 1000)).clamp(0.0, 1.0);
  }

  static double _bearingDelta(double from, double to) {
    var d = to - from;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d;
  }

  void _lerpBearingToward(double target, [double factor = _bearingLerp]) {
    final d = _bearingDelta(_displayBearing, target);
    _displayBearing = (_displayBearing + d * factor) % 360;
  }

  void _maybeUpdatePercent(double p) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPercentMs < 450) return;
    _lastPercentMs = now;
    final pct = (p * 100).round();
    if (_percentNotifier.value != pct) {
      _percentNotifier.value = pct;
    }
  }

  void _startSmoothTracking() {
    _trackTicker?.dispose();
    _trackTicker = createTicker(_onTrackTick)..start();
  }

  void _onTrackTick(Duration elapsed) {
    if (!_canTouchMap || !_ready || _arc.isEmpty) return;
    final p = _progressNow();
    _lerpBearingToward(bearingOnArc(_arc, p));
    _trackProgress = p;
    unawaited(_applyTrackFrame(p, updateFlownLine: _shouldUpdateFlownLine()));
    if (_shouldUpdateNightOverlay()) {
      unawaited(_updateDayNightOverlay());
    }
    _maybeUpdatePercent(p);
  }

  bool _shouldUpdateNightOverlay() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastNightUpdateMs < 45000) return false;
    _lastNightUpdateMs = now;
    return true;
  }

  Future<void> _updateDayNightOverlay() async {
    if (!_canTouchMap) return;
    final map = _map;
    if (map == null) return;
    try {
      await map.style.setStyleSourceProperty(
        'live-night',
        'data',
        buildNightSideGeoJson(),
      );
      await map.style.setStyleSourceProperty(
        'live-terminator',
        'data',
        buildTerminatorLineGeoJson(),
      );
    } catch (_) {}
  }

  bool _shouldUpdateFlownLine() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFlownLineMs < 80) return false;
    _lastFlownLineMs = now;
    return true;
  }

  bool _shouldUpdateAircraftGeo() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastAircraftGeoMs < _aircraftGeoMs) return false;
    _lastAircraftGeoMs = now;
    return true;
  }

  @override
  void didUpdateWidget(covariant LiveFlightMapLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready && oldWidget.followCamera != widget.followCamera && _isFollowing) {
      unawaited(_applyTrackFrame(_trackProgress, updateFlownLine: true));
    }
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
    _arc = buildGreatCircleArc(
      fromLat: widget.fromLat,
      fromLng: widget.fromLng,
      toLat: widget.toLat,
      toLng: widget.toLng,
      segments: 120,
    );
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    if (_map == null || !_mapSessionAlive) return;
    if (_styleLayersAdded) return;
    final preserve = _pendingStyleReload;
    _pendingStyleReload = false;
    await _setupMapLayers(preserveFlightState: preserve);
  }

  Future<void> _setupMapLayers({bool preserveFlightState = false}) async {
    final map = _map;
    if (map == null || !_mapSessionAlive) return;
    _styleLayersAdded = true;

    final progress = _trackProgress.clamp(0.0, 1.0);

    // กลางวัน / กลางคืน — ฝั่งมืด + เส้น terminator (sunset)
    await map.style.addSource(
      GeoJsonSource(id: 'live-night', data: buildNightSideGeoJson()),
    );
    await map.style.addSource(
      GeoJsonSource(id: 'live-terminator', data: buildTerminatorLineGeoJson()),
    );
    await map.style.addLayer(FillLayer(
      id: 'live-night-fill',
      sourceId: 'live-night',
      fillColor: const Color(0xFF040818).toARGB32(),
      fillOpacity: 0.48,
    ));
    await map.style.addLayer(LineLayer(
      id: 'live-terminator-line',
      sourceId: 'live-terminator',
      lineColor: const Color(0xFFFFB347).toARGB32(),
      lineWidth: 2.0,
      lineOpacity: 0.55,
      lineBlur: 0.4,
    ));

    await map.style.addSource(GeoJsonSource(id: 'live-route-full', data: _lineGeoJson(_arc)));
    await map.style.addSource(
      GeoJsonSource(
        id: 'live-route-flown',
        data: _lineGeoJson(arcSlice(_arc, preserveFlightState ? progress : 0)),
      ),
    );
    await map.style.addSource(GeoJsonSource(id: 'live-airports', data: _airportsGeoJson()));

    await map.style.addLayer(LineLayer(
      id: 'live-route-base-casing',
      sourceId: 'live-route-full',
      lineColor: const Color.fromARGB(255, 209, 209, 209).toARGB32(),
      lineWidth: 2.0,
      lineOpacity: 0.62,
      lineDasharray: [2.0, 2.5],
      lineCap: LineCap.ROUND,
    ));
    await map.style.addLayer(LineLayer(
      id: 'live-route-base',
      sourceId: 'live-route-full',
      lineColor: const Color.fromARGB(255, 91, 91, 91).toARGB32(),
      lineWidth: 2.0,
      lineOpacity: 0.92,
      lineDasharray: [2.0, 2.5],
      lineCap: LineCap.ROUND,
    ));
    await map.style.addLayer(LineLayer(
      id: 'live-route-amber',
      sourceId: 'live-route-flown',
      lineColor: AppColors.amber.toARGB32(),
      lineWidth: 5.0,
      lineOpacity: 0.95,
      lineCap: LineCap.ROUND,
      lineJoin: LineJoin.ROUND,
    ));
    await map.style.addLayer(CircleLayer(
      id: 'live-from-dot',
      sourceId: 'live-airports',
      filter: ['==', ['get', 'kind'], 'from'],
      circleRadius: 9,
      circleColor: AppColors.amber2.toARGB32(),
      circleStrokeWidth: 2.5,
      circleStrokeColor: const Color(0xFF0A0B0D).toARGB32(),
    ));
    await map.style.addLayer(CircleLayer(
      id: 'live-to-dot',
      sourceId: 'live-airports',
      filter: ['==', ['get', 'kind'], 'to'],
      circleRadius: 9,
      circleColor: AppColors.amber.toARGB32(),
      circleStrokeWidth: 2.5,
      circleStrokeColor: const Color(0xFF0A0B0D).toARGB32(),
    ));
    await map.style.addLayer(SymbolLayer(
      id: 'live-labels',
      sourceId: 'live-airports',
      textField: '{code}',
      textSize: 12,
      textColor: Colors.white.toARGB32(),
      textHaloColor: Colors.black.toARGB32(),
      textHaloWidth: 1.5,
      textOffset: [0, 1.8],
    ));

    if (_map3dEnabled) {
      if (_mapStyle.supportsStandard3dConfig) {
        await _setMapbox3dBuildings(true);
      }
      await _enableMapboxTerrain();
      await _maybeBoostZoomFor3dBuildings();
    } else if (_mapStyle.supportsStandard3dConfig) {
      await _setMapbox3dBuildings(false);
    }

    final aircraftStart = positionOnArc(_arc, preserveFlightState ? progress : 0);
    await map.style.addSource(
      GeoJsonSource(id: 'live-aircraft', data: _aircraftGeoJson(aircraftStart)),
    );
    await map.style.addLayer(CircleLayer(
      id: 'live-aircraft-glow',
      sourceId: 'live-aircraft',
      circleRadius: 28,
      circleColor: AppColors.amber.toARGB32(),
      circleOpacity: 0.35,
      circleBlur: 0.8,
    ));

    _haloMgr = await map.annotations.createCircleAnnotationManager();
    final startPoint =
        Point(coordinates: Position(aircraftStart[0], aircraftStart[1]));

    _haloAnn = await _haloMgr!.create(CircleAnnotationOptions(
      geometry: startPoint,
      circleRadius: 20,
      circleColor: AppColors.amber.toARGB32(),
      circleOpacity: 0.18,
      circleBlur: 0.5,
    ));

    // เครื่องบินบนแผนที่ — โหมด explore (ซ่อนเมื่อ follow ใช้ overlay กลางจอ)
    _planeMgr = await map.annotations.createPointAnnotationManager();
    final planeBearing = bearingOnArc(_arc, preserveFlightState ? progress : 0);
    _planeAnn = await _planeMgr!.create(PointAnnotationOptions(
      geometry: startPoint,
      textField: '✈',
      textSize: 28,
      textColor: AppColors.amber.toARGB32(),
      textHaloColor: Colors.black.toARGB32(),
      textHaloWidth: 2,
      textRotate: planeBearing + _planeTextRotateOffset,
      textOpacity: _isFollowing ? 0 : 1,
      symbolSortKey: 20,
    ));

    if (preserveFlightState) {
      await _syncMap3dMode();
      _syncExplorePlaneVisibility();
      if (mounted) setState(() => _ready = true);
      _trackTicker ??= createTicker(_onTrackTick);
      if (!_trackTicker!.isActive) _trackTicker!.start();
      await _applyTrackFrame(progress, updateFlownLine: true);
      return;
    }

    _routeZoom = _computeRouteZoom();
    _markProgrammaticCamera(const Duration(milliseconds: 1600));
    await _fitRouteOnce();
    _trackProgress = _progressNow();
    _displayBearing = bearingOnArc(_arc, _trackProgress);
    _percentNotifier.value = (_trackProgress * 100).round();
    setState(() => _ready = true);
    await Future.delayed(const Duration(milliseconds: 400));
    await _resumeTracking();
    _startSmoothTracking();
  }

  double _computeRouteZoom() {
    final span = max(
      (widget.fromLat - widget.toLat).abs(),
      (widget.fromLng - widget.toLng).abs(),
    );
    // มุมมองเริ่มต้น — zoom เข้ากว่า overview แต่ยังเห็นเส้นทาง
    if (span < 2) return 9.5;
    if (span < 5) return 8.5;
    if (span < 12) return 7.5;
    if (span < 25) return 6.5;
    return 5.8;
  }

  double _defaultFollowZoom() {
    final routeZ = _routeZoom ?? 7.0;
    var z = (routeZ + 1.4).clamp(_minZoom, _maxZoom);
    if (_map3dEnabled && _routeLatLngSpan() < 4) {
      z = max(z, _buildingVisibleZoom);
    }
    return z;
  }

  /// Zoom ตอนติดตามเครื่องบิน (ค่าเริ่มต้นหรือที่ผู้ใช้ปรับ)
  double _followZoomLevel() {
    return (_followZoom ?? _defaultFollowZoom()).clamp(_minZoom, _maxZoom);
  }

  double _computeFollowPitch([double? zoom]) {
    final z = zoom ?? _followZoomLevel();
    // ซูมเมือง — pitch สูงขึ้นเพื่อมองตึก 3D ชัด
    if (z >= _buildingVisibleZoom) return 68;
    if (z <= 5.5) return 18;
    if (z <= 7.0) return 38;
    if (z <= 9.0) return 52;
    return 62;
  }

  double _activeFollowPitch([double? zoom]) {
    if (!_map3dEnabled) return 0;
    return _computeFollowPitch(zoom);
  }

  double _routeLatLngSpan() {
    return max(
      (widget.fromLat - widget.toLat).abs(),
      (widget.fromLng - widget.toLng).abs(),
    );
  }

  bool get _canUseStandard3dBuildings =>
      _mapStyle.supportsStandard3dConfig && _map3dEnabled;

  /// เปิด/ปิดตึก 3D ผ่าน config ของ Mapbox Standard (import basemap)
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
      final imports = await map.style.getStyleImports();
      for (final info in imports) {
        final id = info?.id;
        if (id == null || id.isEmpty) continue;
        try {
          await map.style.setStyleImportConfigProperties(id, configs);
        } catch (_) {}
      }
      await map.style.setStyleImportConfigProperties('basemap', configs);
    } catch (_) {
      try {
        for (final entry in configs.entries) {
          await map.style.setStyleImportConfigProperty(
            'basemap',
            entry.key,
            entry.value,
          );
        }
      } catch (_) {}
    }
  }

  Future<void> _enableMapboxTerrain() async {
    final map = _map;
    if (map == null || !_canTouchMap) return;
    try {
      await map.style.setStyleTerrain(
        json.encode({'source': 'mapbox-raster-dem', 'exaggeration': 1.35}),
      );
      return;
    } catch (_) {}
    try {
      await map.style.addSource(
        RasterDemSource(
          id: 'live-terrain-dem',
          url: MapboxResourceUris.terrainDemV1,
        ),
      );
      await map.style.setStyleTerrain(
        json.encode({'source': 'live-terrain-dem', 'exaggeration': 1.35}),
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

  /// เที่ยวสั้น — ซูมเข้าให้ถึงระดับที่เห็นตึก 3D
  Future<void> _maybeBoostZoomFor3dBuildings() async {
    if (!_map3dEnabled || !_isFollowing || _routeLatLngSpan() >= 4) return;
    if (_followZoomLevel() >= _buildingVisibleZoom) return;
    _followZoom = _buildingVisibleZoom;
  }

  Future<void> _syncMap3dMode() async {
    if (_map3dEnabled) {
      if (_mapStyle.supportsStandard3dConfig) {
        await _setMapbox3dBuildings(true);
      }
      await _enableMapboxTerrain();
      await _maybeBoostZoomFor3dBuildings();
    } else {
      if (_mapStyle.supportsStandard3dConfig) {
        await _setMapbox3dBuildings(false);
      }
      await _disableMapboxTerrain();
    }
    if (_isFollowing) {
      await _applyTrackFrame(_trackProgress, updateFlownLine: false);
    }
  }

  /// เปลี่ยนสไตล์โดยไม่สร้าง MapWidget ใหม่ (แก้ iOS recreating_view)
  Future<void> _reloadMapStyle() async {
    final map = _map;
    if (map == null || !_mapSessionAlive) return;

    _pendingStyleReload = true;
    _styleLayersAdded = false;
    _haloMgr = null;
    _haloAnn = null;
    _planeMgr = null;
    _planeAnn = null;
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

  void _showMapStylePicker(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.46,
        minChildSize: 0.38,
        maxChildSize: 0.58,
        expand: false,
        builder: (_, scrollController) => _MapStylePickerSheet(
          scrollController: scrollController,
          selectedId: _mapStyle.id,
          onSelected: (option) {
            Navigator.pop(ctx);
            _selectMapStyle(option);
          },
        ),
      ),
    );
  }

  Future<void> _toggleMap3d() async {
    HapticFeedback.selectionClick();
    setState(() => _map3dEnabled = !_map3dEnabled);
    if (_map3dEnabled) {
      _followZoom = null;
    }
    await _syncMap3dMode();
    if (mounted) setState(() {});
  }

  Future<void> _fitRouteOnce() async {
    final map = _map;
    if (map == null || _arc.isEmpty) return;
    _markProgrammaticCamera(const Duration(milliseconds: 1400));
    final midLat = (widget.fromLat + widget.toLat) / 2;
    final midLng = (widget.fromLng + widget.toLng) / 2;
    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(midLng, midLat)),
        zoom: _routeZoom,
        pitch: 0,
        bearing: 0,
      ),
      MapAnimationOptions(duration: 1200),
    );
  }

  /// จุดบนเส้นทางสำหรับ fit กล้องให้เห็นทั้งเส้นทาง
  List<Point> _routeBoundsPoints() {
    final pts = <Point>[
      Point(coordinates: Position(widget.fromLng, widget.fromLat)),
      Point(coordinates: Position(widget.toLng, widget.toLat)),
    ];
    if (_arc.isEmpty) return pts;
    final step = max(1, _arc.length ~/ 16);
    for (var i = 0; i < _arc.length; i += step) {
      final c = _arc[i];
      pts.add(Point(coordinates: Position(c[0], c[1])));
    }
    final last = _arc.last;
    pts.add(Point(coordinates: Position(last[0], last[1])));
    return pts;
  }

  /// Route overview — แสดงเส้นทางทั้งเส้นพร้อมสนามบินต้นทาง/ปลายทาง
  Future<void> _fitRouteOverview() async {
    final map = _map;
    if (map == null) return;
    _markProgrammaticCamera(const Duration(milliseconds: 1600));
    final coords = _routeBoundsPoints();
    try {
      final padding = MbxEdgeInsets(
        top: 96,
        left: 40,
        bottom: 280,
        right: 88,
      );
      var cam = await map.cameraForCoordinatesPadding(
        coords,
        CameraOptions(bearing: 0, pitch: 0),
        padding,
        null,
        null,
      );
      // ถอยซูมออกเล็กน้อยให้เห็นเส้นทางครบไม่ถูกตัดขอบ
      final z = cam.zoom;
      if (z != null) {
        cam = CameraOptions(
          center: cam.center,
          zoom: (z - 0.65).clamp(_minZoom, _maxZoom),
          bearing: 0,
          pitch: 0,
        );
      } else {
        cam = CameraOptions(
          center: cam.center,
          bearing: 0,
          pitch: 0,
        );
      }
      await map.flyTo(cam, MapAnimationOptions(duration: 1100));
    } catch (_) {
      await _fitRouteOnce();
    }
  }

  Future<void> _showRouteOverview() async {
    HapticFeedback.selectionClick();
    setState(() => _manualOverride = true);
    _syncExplorePlaneVisibility();
    await _fitRouteOverview();
    if (mounted) setState(() {});
  }

  void _enterExploreMode() {
    if (_manualOverride) return;
    HapticFeedback.selectionClick();
    setState(() => _manualOverride = true);
    _syncExplorePlaneVisibility();
  }

  void _syncExplorePlaneVisibility() {
    final plane = _planeAnn;
    if (plane == null || !_canTouchMap) return;
    plane.textOpacity = _isFollowing ? 0 : 1;
    unawaited(_safePointUpdate(plane));
  }

  void _onUserMapGesture() {
    if (!_acceptUserGestures || _manualOverride) return;
    setState(() => _manualOverride = true);
    _syncExplorePlaneVisibility();
  }

  /// Per-frame map sync — setCamera (no flyTo) for smooth follow.
  Future<void> _applyTrackFrame(double p, {required bool updateFlownLine}) async {
    if (!_canTouchMap || !_ready) return;
    final map = _map;
    if (map == null || _arc.isEmpty) return;

    final progress = p.clamp(0.0, 1.0);
    final pos = positionOnArc(_arc, progress);
    final point = Point(coordinates: Position(pos[0], pos[1]));
    final bearing = _displayBearing;
    final planeRotate = bearing + _planeTextRotateOffset;

    if (updateFlownLine) {
      try {
        await map.style.setStyleSourceProperty(
          'live-route-flown',
          'data',
          _lineGeoJson(arcSlice(_arc, progress)),
        );
      } catch (_) {}
    }

    if (_shouldUpdateAircraftGeo()) {
      try {
        await map.style.setStyleSourceProperty(
          'live-aircraft',
          'data',
          _aircraftGeoJson(pos),
        );
      } catch (_) {}
    }

    final halo = _haloAnn;
    if (halo != null) {
      halo.geometry = point;
      unawaited(_safeCircleUpdate(halo));
    }

    final plane = _planeAnn;
    if (plane != null) {
      plane.geometry = point;
      plane.textRotate = planeRotate;
      plane.textOpacity = _isFollowing ? 0 : 1;
      unawaited(_safePointUpdate(plane));
    }

    if (_isFollowing) {
      final smooth = _smoothPosition(pos);
      final camPoint = Point(coordinates: Position(smooth[0], smooth[1]));
      _markProgrammaticCamera(const Duration(milliseconds: 120));
      final followZoom = _followZoomLevel();
      final camOpts = CameraOptions(
        center: camPoint,
        pitch: _activeFollowPitch(followZoom),
        bearing: bearing,
      );
      // ขณะ pinch ไม่บังคับ zoom — ให้ผู้ใช้ซูมอิสระ
      if (!_userAdjustingZoom) {
        camOpts.zoom = followZoom;
      }
      unawaited(map.setCamera(camOpts).catchError((_) {}));
    }
  }

  Future<void> _captureFollowZoomFromCamera() async {
    final map = _map;
    if (map == null || !_isFollowing) return;
    try {
      final cam = await map.getCameraState();
      _followZoom = cam.zoom.clamp(_minZoom, _maxZoom);
    } catch (_) {}
  }

  void _onPinchOrZoomGesture() {
    if (!_acceptUserGestures) return;
    _userAdjustingZoom = true;
    _zoomGestureEndTimer?.cancel();
    _zoomGestureEndTimer = Timer(const Duration(milliseconds: 450), () {
      _userAdjustingZoom = false;
      unawaited(_captureFollowZoomFromCamera());
    });
    // Pinch ซูมขณะ follow — ไม่ออกจากโหมดติดตาม
    if (_isFollowing) return;
    if (!_manualOverride) {
      setState(() => _manualOverride = true);
      _syncExplorePlaneVisibility();
    }
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
    _resetSmoothCamera();
    _syncExplorePlaneVisibility();
    _trackProgress = _progressNow();
    _displayBearing = bearingOnArc(_arc, _trackProgress);

    final map = _map;
    if (map != null && _arc.isNotEmpty) {
      _markProgrammaticCamera(const Duration(milliseconds: 600));
      final pos = positionOnArc(_arc, _trackProgress);
      final point = Point(coordinates: Position(pos[0], pos[1]));
      try {
        await map.flyTo(
          CameraOptions(
            center: point,
            zoom: _followZoomLevel(),
            pitch: _activeFollowPitch(),
            bearing: _displayBearing,
          ),
          MapAnimationOptions(duration: 480),
        );
      } catch (_) {}
    }
    await _applyTrackFrame(_trackProgress, updateFlownLine: true);
    if (mounted) setState(() {});
  }

  void _onUserScroll(MapContentGestureContext _) => _onUserMapGesture();

  void _onUserZoom(MapContentGestureContext _) => _onPinchOrZoomGesture();

  String _aircraftGeoJson(List<double> pos) => jsonEncode({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': {},
            'geometry': {
              'type': 'Point',
              'coordinates': pos,
            },
          },
        ],
      });

  String _lineGeoJson(List<List<double>> coords) => jsonEncode({
        'type': 'FeatureCollection',
        'features': coords.isEmpty
            ? []
            : [
                {
                  'type': 'Feature',
                  'properties': {},
                  'geometry': {'type': 'LineString', 'coordinates': coords},
                },
              ],
      });

  String _airportsGeoJson() => jsonEncode({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': {'code': widget.fromCode, 'kind': 'from'},
            'geometry': {
              'type': 'Point',
              'coordinates': [widget.fromLng, widget.fromLat],
            },
          },
          {
            'type': 'Feature',
            'properties': {'code': widget.toCode, 'kind': 'to'},
            'geometry': {
              'type': 'Point',
              'coordinates': [widget.toLng, widget.toLat],
            },
          },
        ],
      });

  @override
  Widget build(BuildContext context) {
    final isFollowing = _isFollowing;

    return DeferredMapHost(
      onMountChanged: _onMapHostMountChanged,
      builder: (context) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final followBottom = constraints.maxHeight * 0.46;

            return Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: SizedBox.expand(
                    child: MapWidget(
                      key: const ValueKey('live-flight-map'),
                      styleUri: _mapStyle.styleUri,
                      onMapCreated: _onMapCreated,
                      onStyleLoadedListener: _onStyleLoaded,
                      onScrollListener: _onUserScroll,
                      onZoomListener: _onUserZoom,
                    ),
                  ),
                ),
            if (!_ready)
              const Positioned.fill(child: _MapLoadingOverlay()),
            // 2D plane icon — always centered (camera follows the aircraft)
            if (_ready && _isFollowing)
              IgnorePointer(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (context2, child2) => _PlaneOverlay(
                      pulse: _pulseCtrl.value,
                    ),
                  ),
                ),
              ),
            if (_ready && !widget.uiHidden) ...[
              Positioned(
                left: 16,
                right: 16,
                top: MediaQuery.paddingOf(context).top + 52,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ValueListenableBuilder<int>(
                      valueListenable: _percentNotifier,
                      builder: (context, pct, _) => _MapFlightStatusBar(
                        fromCode: widget.fromCode,
                        toCode: widget.toCode,
                        percent: pct,
                        isFollowing: isFollowing,
                        mapStyleLabel: _mapStyle.label,
                        map3dEnabled: _map3dEnabled,
                        showBuildingHint: _canUseStandard3dBuildings,
                        followZoom: _followZoomLevel(),
                        buildingVisibleZoom: _buildingVisibleZoom,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _DayNightLegend(),
                  ],
                ),
              ),
            
              Positioned(
                right: 14,
                bottom: followBottom - 72,
                child: _MapViewControls(
                  isFollowing: isFollowing,
                  map3dEnabled: _map3dEnabled,
                  onPickStyle: () => _showMapStylePicker(context),
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
          ],
            );
          },
        );
      },
    );
  }
}

// ─── Map overlays ────────────────────────────────────────────────────────────

class _MapLoadingOverlay extends StatelessWidget {
  const _MapLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0C0D10).withValues(alpha: 0.55),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.amber,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Loading flight map…',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 2D plane overlay ────────────────────────────────────────────────────────

class _PlaneOverlay extends StatelessWidget {
  const _PlaneOverlay({required this.pulse});

  final double pulse;

  static const double _iconUpRadians = pi / 90;

  @override
  Widget build(BuildContext context) {
    final p2 = (pulse + 0.5) % 1.0;
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _PulseRing(radius: 32 + pulse * 26, opacity: (1 - pulse) * 0.55),
          _PulseRing(radius: 32 + p2 * 26, opacity: (1 - p2) * 0.55),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.amber.withValues(alpha: 0.5),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          Transform.rotate(
            angle: _iconUpRadians,
            child: const _StrokedPlaneIcon(
              size: 52,
              fillColor: AppColors.amber,
              strokeColor: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

/// ไอคอนเครื่องบินพร้อมขอบตามรูป (ไม่ใช่วงกลม)
class _StrokedPlaneIcon extends StatelessWidget {
  const _StrokedPlaneIcon({
    required this.size,
    required this.fillColor,
    required this.strokeColor,
  });

  final double size;
  final Color fillColor;
  final Color strokeColor;

  static const _icon = Icons.airplanemode_active_rounded;

  @override
  Widget build(BuildContext context) {
    // ซ้อน icon ชั้นนอกเป็นขอบ outline รอบ silhouette เครื่องบิน
    const strokeOffsets = <Offset>[
      Offset(-1.4, 0),
      Offset(1.4, 0),
      Offset(0, -1.4),
      Offset(0, 1.4),
      Offset(-1, -1),
      Offset(1, -1),
      Offset(-1, 1),
      Offset(1, 1),
    ];

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        for (final o in strokeOffsets)
          Transform.translate(
            offset: o,
            child: Icon(_icon, size: size, color: strokeColor),
          ),
        Icon(_icon, size: size, color: fillColor),
      ],
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({required this.radius, required this.opacity});

  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final d = radius * 2;
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.amber.withValues(alpha: opacity.clamp(0.0, 1.0)),
          width: 1.8,
        ),
      ),
    );
  }
}

// ─── Map overlays ─────────────────────────────────────────────────────────────

/// เส้นตารางจำลองแผนที่บนการ์ด preview
class _MapPreviewGridPainter extends CustomPainter {
  _MapPreviewGridPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 0.8;
    const step = 14.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final route = Paint()
      ..shader = LinearGradient(
        colors: [
          accent.withValues(alpha: 0.9),
          AppColors.amber2.withValues(alpha: 0.5),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.35,
        size.width * 0.88,
        size.height * 0.28,
      );
    canvas.drawPath(path, route);

    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.28),
      5,
      Paint()..color = AppColors.amber,
    );
  }

  @override
  bool shouldRepaint(covariant _MapPreviewGridPainter old) =>
      old.accent != accent;
}

class _MapStyleOptionCard extends StatelessWidget {
  const _MapStyleOptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final LiveMapStyleOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedScale(
        scale: selected ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? option.accent.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.12),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: option.accent.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: -4,
                ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 108,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              option.previewTop,
                              option.previewBottom,
                            ],
                          ),
                        ),
                      ),
                      CustomPaint(
                        painter: _MapPreviewGridPainter(accent: option.accent),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.45),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.layers_rounded,
                                size: 12,
                                color: option.accent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '3D',
                                style: TextStyle(
                                  color: option.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Center(
                        child: Icon(
                          option.icon,
                          size: 40,
                          color: Colors.white.withValues(
                            alpha: selected ? 0.95 : 0.7,
                          ),
                          shadows: [
                            Shadow(
                              color: option.accent.withValues(alpha: 0.6),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: option.accent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: option.accent.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Color(0xFF0C0D10),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  color: const Color(0xFF141820),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: selected ? 0.98 : 0.88,
                          ),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        option.subtitleEn,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        option.subtitleLo,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.38),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapStylePickerSheet extends StatelessWidget {
  const _MapStylePickerSheet({
    required this.scrollController,
    required this.selectedId,
    required this.onSelected,
  });

  final ScrollController scrollController;
  final String selectedId;
  final ValueChanged<LiveMapStyleOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF222833).withValues(alpha: 0.96),
                const Color(0xFF0E1016).withValues(alpha: 0.98),
              ],
            ),
            border: Border(
              top: BorderSide(color: AppColors.amber.withValues(alpha: 0.25)),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + bottom),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.amber.withValues(alpha: 0.35),
                          AppColors.amber.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.amber.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.map_rounded,
                      color: AppColors.amber,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Map style',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.96),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pick your flight view',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.48),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'ເລືອກຮູບແບບແຜນທີ່',
                          style: TextStyle(
                            color: AppColors.amber.withValues(alpha: 0.65),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < LiveMapStyleOptions.all.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: _MapStyleOptionCard(
                        option: LiveMapStyleOptions.all[i],
                        selected:
                            LiveMapStyleOptions.all[i].id == selectedId,
                        onTap: () => onSelected(LiveMapStyleOptions.all[i]),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.swipe_vertical_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Drag down to close · map reloads when you switch',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapFlightStatusBar extends StatelessWidget {
  const _MapFlightStatusBar({
    required this.fromCode,
    required this.toCode,
    required this.percent,
    required this.isFollowing,
    required this.mapStyleLabel,
    required this.map3dEnabled,
    required this.showBuildingHint,
    required this.followZoom,
    required this.buildingVisibleZoom,
  });

  final String fromCode;
  final String toCode;
  final int percent;
  final bool isFollowing;
  final String mapStyleLabel;
  final bool map3dEnabled;
  final bool showBuildingHint;
  final double followZoom;
  final double buildingVisibleZoom;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF16181D).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFollowing
              ? AppColors.amber.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isFollowing ? Icons.radar_rounded : Icons.gps_not_fixed_rounded,
            size: 18,
            color: isFollowing ? AppColors.amber : Colors.white54,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFollowing
                      ? (map3dEnabled
                          ? '3D map · tracking airplane'
                          : '2D map · tracking airplane')
                      : 'Explore mode · drag, pinch, rotate freely',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  mapStyleLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (showBuildingHint && followZoom < buildingVisibleZoom)
                  Text(
                    'Pinch zoom in (≥${buildingVisibleZoom.toStringAsFixed(0)}) to see 3D buildings',
                    style: TextStyle(
                      color: AppColors.amber.withValues(alpha: 0.85),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  '$fromCode → $toCode · $percent% along route',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isFollowing
                  ? AppColors.amber.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$percent%',
              style: TextStyle(
                color: isFollowing ? AppColors.amber : Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayNightLegend extends StatelessWidget {
  const _DayNightLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.wb_sunny_rounded, size: 14, color: Colors.amber.shade300),
          const SizedBox(width: 6),
          Text(
            'Daylight',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 28,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFB347).withValues(alpha: 0.9),
                  const Color(0xFF040818).withValues(alpha: 0.9),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Icon(Icons.nightlight_round, size: 14, color: Colors.indigo.shade200),
          const SizedBox(width: 6),
          Text(
            'Night side',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}


// ─── Map view controls ───────────────────────────────────────────────────────

class _MapViewControls extends StatelessWidget {
  const _MapViewControls({
    required this.isFollowing,
    required this.map3dEnabled,
    required this.onPickStyle,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onExplore,
    required this.onRouteOverview,
    required this.onToggle3d,
    required this.onFollow,
  });

  final bool isFollowing;
  final bool map3dEnabled;
  final VoidCallback onPickStyle;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onExplore;
  final VoidCallback onRouteOverview;
  final VoidCallback onToggle3d;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ZoomBtn(
          icon: isFollowing ? Icons.explore_outlined : Icons.my_location_rounded,
          onTap: isFollowing ? onExplore : onFollow,
          amber: true,
          tooltip: isFollowing ? 'Explore map' : 'Follow flight',
        ),
        const SizedBox(height: 8),
        _ZoomBtn(
          icon: Icons.public_rounded,
          onTap: onRouteOverview,
          tooltip: 'Route overview',
        ),
        const SizedBox(height: 8),
        _ZoomBtn(
          icon: Icons.layers_rounded,
          onTap: onPickStyle,
          tooltip: 'Map style',
        ),
        const SizedBox(height: 8),
        _ZoomBtn(
          icon: map3dEnabled ? Icons.view_in_ar_rounded : Icons.map_rounded,
          onTap: onToggle3d,
          amber: map3dEnabled,
          tooltip: map3dEnabled ? 'Switch to 2D map' : 'Switch to 3D map',
        ),
        const SizedBox(height: 8),
        _ZoomBtn(icon: Icons.add_rounded, onTap: onZoomIn),
        const SizedBox(height: 8),
        _ZoomBtn(icon: Icons.remove_rounded, onTap: onZoomOut),
      ],
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  const _ZoomBtn({
    required this.icon,
    required this.onTap,
    this.amber = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool amber;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: amber
                ? AppColors.amber.withValues(alpha: 0.75)
                : Colors.white.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10),
          ],
        ),
        child: Icon(
          icon,
          size: 22,
          color: amber ? AppColors.amber : Colors.white.withValues(alpha: 0.88),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

