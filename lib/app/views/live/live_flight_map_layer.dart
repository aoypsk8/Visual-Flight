import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../utils/app_colors.dart';
import '../../utils/flight_route_arc.dart';

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

  @override
  State<LiveFlightMapLayer> createState() => _LiveFlightMapLayerState();
}

class _LiveFlightMapLayerState extends State<LiveFlightMapLayer>
    with TickerProviderStateMixin {
  MapboxMap? _map;
  CircleAnnotationManager? _haloMgr;
  CircleAnnotation? _haloAnn;
  List<List<double>> _arc = [];
  bool _ready = false;
  double? _routeZoom;
  bool _manualOverride = false;
  double _zoomOffset = 0;

  Ticker? _trackTicker;
  double _trackProgress = 0;
  double _displayBearing = 0;
  int _lastFlownLineMs = 0;
  DateTime _ignoreUserGesturesUntil = DateTime.fromMillisecondsSinceEpoch(0);

  late final AnimationController _pulseCtrl;

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
    _trackTicker?.dispose();
    _pulseCtrl.dispose();
    super.dispose();
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

  void _lerpBearingToward(double target, double factor) {
    final d = _bearingDelta(_displayBearing, target);
    _displayBearing = (_displayBearing + d * factor) % 360;
  }

  void _startSmoothTracking() {
    _trackTicker?.dispose();
    _trackTicker = createTicker(_onTrackTick)..start();
  }

  void _onTrackTick(Duration elapsed) {
    if (!_ready || _arc.isEmpty) return;
    final p = _progressNow();
    _lerpBearingToward(bearingOnArc(_arc, p), 0.22);
    _trackProgress = p;
    unawaited(_applyTrackFrame(p, updateFlownLine: _shouldUpdateFlownLine()));
    if (mounted) setState(() {});
  }

  bool _shouldUpdateFlownLine() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFlownLineMs < 80) return false;
    _lastFlownLineMs = now;
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
    _arc = buildGreatCircleArc(
      fromLat: widget.fromLat,
      fromLng: widget.fromLng,
      toLat: widget.toLat,
      toLng: widget.toLng,
      segments: 120,
    );

    await map.style.addSource(GeoJsonSource(id: 'live-route-full', data: _lineGeoJson(_arc)));
    await map.style.addSource(GeoJsonSource(id: 'live-route-flown', data: _lineGeoJson([])));
    await map.style.addSource(GeoJsonSource(id: 'live-airports', data: _airportsGeoJson()));

    await map.style.addLayer(LineLayer(
      id: 'live-route-base',
      sourceId: 'live-route-full',
      lineColor: Colors.white.toARGB32(),
      lineWidth: 2.5,
      lineOpacity: 0.4,
      lineDasharray: [1.5, 2.0],
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
      circleColor: Colors.white.toARGB32(),
      circleStrokeWidth: 2.5,
      circleStrokeColor: AppColors.amber.toARGB32(),
    ));
    await map.style.addLayer(CircleLayer(
      id: 'live-to-dot',
      sourceId: 'live-airports',
      filter: ['==', ['get', 'kind'], 'to'],
      circleRadius: 9,
      circleColor: AppColors.amber.toARGB32(),
      circleStrokeWidth: 2.5,
      circleStrokeColor: Colors.white.toARGB32(),
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

    final aircraftStart = positionOnArc(_arc, 0);
    await map.style.addSource(
      GeoJsonSource(id: 'live-aircraft', data: _aircraftGeoJson(aircraftStart)),
    );
    await map.style.addLayer(CircleLayer(
      id: 'live-aircraft-glow',
      sourceId: 'live-aircraft',
      circleRadius: 24,
      circleColor: AppColors.amber.toARGB32(),
      circleOpacity: 0.4,
      circleBlur: 0.6,
    ));
    await map.style.addLayer(CircleLayer(
      id: 'live-aircraft-dot',
      sourceId: 'live-aircraft',
      circleRadius: 11,
      circleColor: AppColors.amber.toARGB32(),
      circleStrokeWidth: 3,
      circleStrokeColor: Colors.white.toARGB32(),
    ));

    _haloMgr = await map.annotations.createCircleAnnotationManager();
    final start = positionOnArc(_arc, 0);
    final startPoint = Point(coordinates: Position(start[0], start[1]));

    _haloAnn = await _haloMgr!.create(CircleAnnotationOptions(
      geometry: startPoint,
      circleRadius: 20,
      circleColor: AppColors.amber.toARGB32(),
      circleOpacity: 0.18,
      circleBlur: 0.5,
    ));

    _routeZoom = _computeRouteZoom();
    _markProgrammaticCamera(const Duration(milliseconds: 1600));
    await _fitRouteOnce();
    _trackProgress = _progressNow();
    _displayBearing = bearingOnArc(_arc, _trackProgress);
    setState(() => _ready = true);
    await Future.delayed(const Duration(milliseconds: 400));
    await _resumeTracking();
    _startSmoothTracking();
  }

  double _computeRouteZoom() {
    final span = math.max(
      (widget.fromLat - widget.toLat).abs(),
      (widget.fromLng - widget.toLng).abs(),
    );
    if (span < 2) return 9.5;
    if (span < 5) return 8.0;
    if (span < 12) return 7.0;
    return 6.0;
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
        pitch: 48,
        bearing: 0,
      ),
      MapAnimationOptions(duration: 1200),
    );
  }

  /// Per-frame map sync — setCamera (no flyTo) for smooth follow.
  Future<void> _applyTrackFrame(double p, {required bool updateFlownLine}) async {
    final map = _map;
    if (map == null || _arc.isEmpty) return;

    final progress = p.clamp(0.0, 1.0);
    final pos = positionOnArc(_arc, progress);
    final point = Point(coordinates: Position(pos[0], pos[1]));
    final bearing = _displayBearing;

    if (updateFlownLine) {
      try {
        await map.style.setStyleSourceProperty(
          'live-route-flown',
          'data',
          _lineGeoJson(arcSlice(_arc, progress)),
        );
      } catch (_) {}
    }

    try {
      await map.style.setStyleSourceProperty(
        'live-aircraft',
        'data',
        _aircraftGeoJson(pos),
      );
    } catch (_) {}

    final halo = _haloAnn;
    if (halo != null && _haloMgr != null) {
      halo.geometry = point;
      unawaited(_haloMgr!.update(halo));
    }

    if (_isFollowing) {
      _markProgrammaticCamera(const Duration(milliseconds: 120));
      final followZoom = (13.5 + _zoomOffset).clamp(5.0, 20.0);
      unawaited(
        map
            .setCamera(
              CameraOptions(
                center: point,
                zoom: followZoom,
                pitch: 58,
                bearing: bearing,
              ),
            )
            .catchError((_) {}),
      );
    }
  }

  Future<void> _zoomIn() async {
    setState(() => _zoomOffset = (_zoomOffset + 1).clamp(-5.0, 5.0));
    final map = _map;
    if (map == null) return;
    _markProgrammaticCamera(const Duration(milliseconds: 400));
    final cam = await map.getCameraState();
    await map.flyTo(
      CameraOptions(zoom: (cam.zoom + 1).clamp(1.0, 20.0)),
      MapAnimationOptions(duration: 300),
    );
  }

  Future<void> _zoomOut() async {
    setState(() => _zoomOffset = (_zoomOffset - 1).clamp(-5.0, 5.0));
    final map = _map;
    if (map == null) return;
    _markProgrammaticCamera(const Duration(milliseconds: 400));
    final cam = await map.getCameraState();
    await map.flyTo(
      CameraOptions(zoom: (cam.zoom - 1).clamp(1.0, 20.0)),
      MapAnimationOptions(duration: 300),
    );
  }

  Future<void> _resumeTracking() async {
    setState(() {
      _manualOverride = false;
      _zoomOffset = 0;
    });
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
            zoom: 13.5,
            pitch: 58,
            bearing: _displayBearing,
          ),
          MapAnimationOptions(duration: 480),
        );
      } catch (_) {}
    }
    await _applyTrackFrame(_trackProgress, updateFlownLine: true);
    if (mounted) setState(() {});
  }

  void _onUserScroll(MapContentGestureContext _) {
    if (!_acceptUserGestures || _manualOverride) return;
    setState(() => _manualOverride = true);
  }

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
    final pct = (_trackProgress * 100).round();

    return LayoutBuilder(
      builder: (context, constraints) {
        // วางปุ่ม Follow เหนือการ์ด HUD (iPad / phone)
        final followBottom = constraints.maxHeight * 0.46;

        return Stack(
          fit: StackFit.expand,
          children: [
            MapWidget(
              styleUri: 'mapbox://styles/mapbox/satellite-streets-v12',
              onMapCreated: _onMapCreated,
              onScrollListener: _onUserScroll,
            ),
            if (!_ready)
              const Positioned.fill(child: _MapLoadingOverlay()),
            // เครื่องบิน 3D กลางจอเมื่อติดตามอยู่
            if (_ready && isFollowing)
              IgnorePointer(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, _) => _Plane3DView(
                      bearing: _displayBearing,
                      pulse: _pulseCtrl.value,
                    ),
                  ),
                ),
              ),
            // สถานะ + progress บนแผนที่
            if (_ready)
              Positioned(
                left: 16,
                right: 16,
                top: MediaQuery.paddingOf(context).top + 52,
                child: _MapFlightStatusBar(
                  fromCode: widget.fromCode,
                  toCode: widget.toCode,
                  percent: pct,
                  isFollowing: isFollowing,
                ),
              ),
            // ปุ่ม Follow เด่นเมื่อหลุดติดตาม
            if (_ready && _manualOverride)
              Positioned(
                left: 20,
                right: 20,
                bottom: followBottom,
                child: _FollowFlightCard(
                  percent: pct,
                  onFollow: () {
                    HapticFeedback.mediumImpact();
                    unawaited(_resumeTracking());
                  },
                ),
              ),
            if (_ready)
              Positioned(
                right: 14,
                bottom: followBottom - 72,
                child: _ZoomControls(
                  onZoomIn: _zoomIn,
                  onZoomOut: _zoomOut,
                  onReCenter: () {
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

// ─── 3D Plane overlay ────────────────────────────────────────────────────────

class _Plane3DView extends StatelessWidget {
  const _Plane3DView({required this.bearing, required this.pulse});

  final double bearing;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final p2 = (pulse + 0.5) % 1.0;
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse ring 1
          _PulseRing(radius: 34 + pulse * 28, opacity: (1 - pulse) * 0.5),
          // Pulse ring 2 (offset phase)
          _PulseRing(radius: 34 + p2 * 28, opacity: (1 - p2) * 0.5),
          // Soft amber glow
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.amber.withValues(alpha: 0.55),
                  blurRadius: 26,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          // 3D aircraft, rotated by bearing
          Transform.rotate(
            angle: bearing * math.pi / 180,
            child: const CustomPaint(
              size: Size(72, 72),
              painter: _PlanePainter(),
            ),
          ),
        ],
      ),
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

class _PlanePainter extends CustomPainter {
  const _PlanePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // ── amber engine exhaust glow behind fuselage ──
    canvas.drawCircle(
      Offset(cx, cy + 20),
      14,
      Paint()
        ..color = AppColors.amber.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // ── drop shadow ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + 1.5, cy + 2), width: 10, height: 42),
        const Radius.circular(5),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // ── wings ──
    final wingShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0xFFCDD7E2), Color(0xFF8EA3B2)],
    ).createShader(Rect.fromCenter(center: Offset(cx, cy + 4), width: 64, height: 30));
    final wingPaint = Paint()..shader = wingShader;

    // left wing
    final lWing = Path()
      ..moveTo(cx - 4, cy - 5)
      ..lineTo(cx - 30, cy + 10)
      ..lineTo(cx - 22, cy + 17)
      ..lineTo(cx - 2, cy + 7)
      ..close();
    canvas.drawPath(lWing, wingPaint);

    // right wing
    final rWing = Path()
      ..moveTo(cx + 4, cy - 5)
      ..lineTo(cx + 30, cy + 10)
      ..lineTo(cx + 22, cy + 17)
      ..lineTo(cx + 2, cy + 7)
      ..close();
    canvas.drawPath(rWing, wingPaint);

    // ── tail fins ──
    final tailPaint = Paint()..color = const Color(0xFFAABBC8);

    final lTail = Path()
      ..moveTo(cx - 3, cy + 14)
      ..lineTo(cx - 14, cy + 21)
      ..lineTo(cx - 11, cy + 23)
      ..lineTo(cx - 2, cy + 18)
      ..close();
    canvas.drawPath(lTail, tailPaint);

    final rTail = Path()
      ..moveTo(cx + 3, cy + 14)
      ..lineTo(cx + 14, cy + 21)
      ..lineTo(cx + 11, cy + 23)
      ..lineTo(cx + 2, cy + 18)
      ..close();
    canvas.drawPath(rTail, tailPaint);

    // ── fuselage ──
    final fuselageShader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: const [Color(0xFFEEF4FA), Colors.white, Color(0xFFCCD6E2)],
      stops: const [0.0, 0.35, 1.0],
    ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: 14, height: 44));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: 11, height: 44),
        const Radius.circular(5.5),
      ),
      Paint()..shader = fuselageShader,
    );

    // fuselage highlight
    canvas.drawLine(
      Offset(cx - 2, cy - 20),
      Offset(cx - 2, cy + 18),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.65)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );

    // ── engine nacelles ──
    final enginePaint = Paint()..color = const Color(0xFF5A6E7A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - 17, cy + 6), width: 5, height: 11),
        const Radius.circular(2.5),
      ),
      enginePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + 17, cy + 6), width: 5, height: 11),
        const Radius.circular(2.5),
      ),
      enginePaint,
    );

    // engine fan reflection
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 17, cy + 3), width: 4, height: 3),
      Paint()..color = Colors.white.withValues(alpha: 0.3),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 17, cy + 3), width: 4, height: 3),
      Paint()..color = Colors.white.withValues(alpha: 0.3),
    );

    // ── nose cone ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 22), width: 9, height: 7),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF5A7080),
    );

    // ── cockpit windows ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 14), width: 6, height: 5),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF5AACDD).withValues(alpha: 0.9),
    );

    // cockpit reflection
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 1, cy - 15), width: 2.5, height: 2),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );

    // ── wingtip nav lights ──
    canvas.drawCircle(
      Offset(cx - 29, cy + 11),
      2.0,
      Paint()
        ..color = Colors.redAccent.withValues(alpha: 0.92)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawCircle(
      Offset(cx + 29, cy + 11),
      2.0,
      Paint()
        ..color = const Color(0xFF00FF88).withValues(alpha: 0.92)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    // ── amber exhaust dot ──
    canvas.drawCircle(
      Offset(cx, cy + 24),
      3.0,
      Paint()
        ..color = AppColors.amber.withValues(alpha: 0.75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
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

class _MapFlightStatusBar extends StatelessWidget {
  const _MapFlightStatusBar({
    required this.fromCode,
    required this.toCode,
    required this.percent,
    required this.isFollowing,
  });

  final String fromCode;
  final String toCode;
  final int percent;
  final bool isFollowing;

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
                  isFollowing ? 'Tracking airplane' : 'Map view — not following',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

class _FollowFlightCard extends StatelessWidget {
  const _FollowFlightCard({
    required this.percent,
    required this.onFollow,
  });

  final int percent;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 12,
      shadowColor: Colors.black54,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onFollow,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E2028).withValues(alpha: 0.96),
                const Color(0xFF2A2218).withValues(alpha: 0.96),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.amber.withValues(alpha: 0.75),
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.amber.withValues(alpha: 0.22),
                    border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.6),
                    ),
                  ),
                  child: const Icon(
                    Icons.flight_rounded,
                    color: AppColors.amber,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Follow your flight',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Airplane is at $percent% · tap to center map & track live',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.amber,
                  ),
                  child: const Icon(
                    Icons.near_me_rounded,
                    color: Color(0xFF1A1408),
                    size: 24,
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

// ─── Zoom controls ───────────────────────────────────────────────────────────

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReCenter,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReCenter;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ZoomBtn(
          icon: Icons.my_location_rounded,
          onTap: onReCenter,
          amber: true,
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
  const _ZoomBtn({required this.icon, required this.onTap, this.amber = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool amber;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
  }
}

