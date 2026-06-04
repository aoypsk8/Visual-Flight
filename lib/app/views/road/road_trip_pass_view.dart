import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../../config/api_urls.dart';
import '../../models/road_trip_session.dart';
import '../../utils/app_colors.dart';
import '../../utils/flight_route_utils.dart';
import '../../widgets/common/app_text.dart';
import '../../widgets/map/deferred_map_host.dart';
import 'road_live_view.dart';

const double _kTearRatio = 0.72;
const double _kMaxDragPx = 260.0;
const double _kSnapThreshold = 0.48;

// ─────────────────────────────────────────────────────────────────────────────
// Entry widget
// ─────────────────────────────────────────────────────────────────────────────

class RoadTripPassView extends StatefulWidget {
  final String fromCity;
  final String fromCountry;
  final String toCity;
  final String toCountry;
  final String seatCode;
  final double distanceKm;
  final Duration duration;
  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;
  final List<List<double>> routeCoords;

  const RoadTripPassView({
    super.key,
    required this.fromCity,
    required this.fromCountry,
    required this.toCity,
    required this.toCountry,
    required this.seatCode,
    required this.distanceKm,
    required this.duration,
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
    this.routeCoords = const [],
  });

  @override
  State<RoadTripPassView> createState() => _RoadTripPassState();
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class _RoadTripPassState extends State<RoadTripPassView>
    with TickerProviderStateMixin {
  late final AnimationController _tearCtrl;
  late final AnimationController _hintCtrl;

  late final String _dateStr;
  late final String _durationStr;
  late final String _distanceStr;

  bool _isDragging = false;
  bool _hintActive = false;
  bool _haptic20 = false;
  bool _haptic50 = false;
  bool _launched = false;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _dateStr =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    _durationStr = FlightRouteUtils.formatDurationCompact(widget.duration);
    _distanceStr = FlightRouteUtils.formatDistance(widget.distanceKm);

    _tearCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _hintCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _tearCtrl.addStatusListener(_onTearStatusChanged);

    _scheduleHint();
  }

  @override
  void dispose() {
    _tearCtrl.dispose();
    _hintCtrl.dispose();
    super.dispose();
  }

  // ── Map ───────────────────────────────────────────────────────────────────

  Future<void> _onMapCreated(MapboxMap map) async {
    final fl = widget.fromLat;
    final flng = widget.fromLng;
    final tl = widget.toLat;
    final tlng = widget.toLng;
    if (fl != null && flng != null && tl != null && tlng != null) {
      final midLat = (fl + tl) / 2;
      final midLng = (flng + tlng) / 2;
      final span = math.max((fl - tl).abs(), (flng - tlng).abs());
      final zoom = span < 2
          ? 9.0
          : span < 5
              ? 7.0
              : span < 10
                  ? 6.0
                  : span < 20
                      ? 5.0
                      : 4.5;
      await map.setCamera(CameraOptions(
        center: Point(coordinates: Position(midLng, midLat)),
        zoom: zoom,
        pitch: 40.0,
        bearing: 0,
      ));
    }
  }

  // ── Hint ──────────────────────────────────────────────────────────────────

  void _scheduleHint({Duration delay = const Duration(seconds: 2)}) {
    Future.delayed(delay, () {
      if (mounted && !_isDragging && _tearCtrl.value < 0.01) {
        setState(() => _hintActive = true);
        _hintCtrl.repeat();
      }
    });
  }

  void _stopHint() {
    if (!_hintActive) return;
    setState(() => _hintActive = false);
    _hintCtrl.stop();
    _hintCtrl.value = 0.0;
  }

  // ── Drag ──────────────────────────────────────────────────────────────────

  void _onDragStart(DragStartDetails _) {
    _stopHint();
    _isDragging = true;
    _haptic20 = false;
    _haptic50 = false;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_isDragging) return;
    final delta = d.delta.dx / _kMaxDragPx;
    final next = (_tearCtrl.value + delta).clamp(0.0, 1.0);
    _tearCtrl.value = next;
    if (!_haptic20 && next >= 0.20) {
      _haptic20 = true;
      HapticFeedback.lightImpact();
    }
    if (!_haptic50 && next >= 0.50) {
      _haptic50 = true;
      HapticFeedback.mediumImpact();
    }
  }

  void _onDragEnd(DragEndDetails d) {
    _isDragging = false;
    final progress = _tearCtrl.value;
    final rightVelocity = d.velocity.pixelsPerSecond.dx;
    if (progress >= _kSnapThreshold || rightVelocity > 500) {
      _completeTear();
    } else {
      _snapBack();
    }
  }

  void _onDragCancel() {
    _isDragging = false;
    _snapBack();
  }

  // ── Tear / snap ────────────────────────────────────────────────────────────

  void _onTearStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_tearCtrl.value < 0.99) return;
    _launchLiveIfReady();
  }

  void _completeTear() {
    if (_launched) return;
    _stopHint();
    if (_tearCtrl.value >= 0.99) {
      _launchLiveIfReady();
      return;
    }
    unawaited(
      _tearCtrl
          .animateTo(
            1.0,
            duration: const Duration(milliseconds: 480),
            curve: Curves.easeInCubic,
          )
          .whenComplete(() {
            if (_tearCtrl.value >= 0.99) _launchLiveIfReady();
          }),
    );
  }

  void _launchLiveIfReady() {
    if (_launched || !mounted) return;
    if (_tearCtrl.value < 0.99) return;
    _launched = true;
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final session = RoadTripSession(
        fromCity: widget.fromCity,
        fromCountry: widget.fromCountry,
        toCity: widget.toCity,
        toCountry: widget.toCountry,
        seatCode: widget.seatCode,
        totalKm: widget.distanceKm,
        totalSeconds: widget.duration.inSeconds,
        startedAt: DateTime.now(),
        fromLat: widget.fromLat ?? 0.0,
        fromLng: widget.fromLng ?? 0.0,
        toLat: widget.toLat ?? 0.0,
        toLng: widget.toLng ?? 0.0,
        routeCoords: widget.routeCoords,
      );
      Get.off(() => RoadLiveView(session: session));
    });
  }

  VoidCallback? _startDriveTapHandler(double t) {
    if (_launched) return null;
    if (t >= 0.99) return _launchLiveIfReady;
    if (_isDragging || _tearCtrl.isAnimating) return null;
    return _completeTear;
  }

  void _snapBack() {
    _tearCtrl
        .animateTo(
          0.0,
          duration: const Duration(milliseconds: 550),
          curve: Curves.elasticOut,
        )
        .then((_) {
          if (!mounted) return;
          _haptic20 = false;
          _haptic50 = false;
          _scheduleHint(delay: const Duration(seconds: 3));
        });
  }

  // ── Ticket builder ─────────────────────────────────────────────────────────

  Widget _buildTearable(double t) {
    final dragGlow =
        (t * 1.8).clamp(0.0, 1.0) * math.max(0.0, 1.0 - t * 1.2);
    final hintGlow = _hintActive
        ? math.max(0.0, math.sin(_hintCtrl.value * math.pi)) * 0.65
        : 0.0;
    final perfGlow = math.max(dragGlow, hintGlow);

    Widget card({double glow = 0.0}) => _RoadTicketCard(
          fromCity: widget.fromCity,
          toCity: widget.toCity,
          seatCode: widget.seatCode,
          distanceStr: _distanceStr,
          durationStr: _durationStr,
          dateStr: _dateStr,
          perfGlow: glow,
        );

    if (t < 0.001) {
      return card(glow: perfGlow);
    }

    final botAngle = 0.22 * t;
    final botOffset = Offset(48 * t, 68 * t);
    final botFade =
        t < 0.68 ? 1.0 : (1.0 - (t - 0.68) / 0.32).clamp(0.0, 1.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Invisible placeholder — keeps stack height stable.
        Opacity(opacity: 0, child: card()),

        // Top portion (info section) — stays completely still.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ClipRect(
            child: Align(
              heightFactor: _kTearRatio,
              alignment: Alignment.topCenter,
              child: card(glow: perfGlow),
            ),
          ),
        ),

        // Bottom portion (barcode stub) — peels away.
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: botFade,
            child: Transform.translate(
              offset: botOffset,
              child: Transform.rotate(
                angle: botAngle,
                alignment: Alignment.topCenter,
                child: ClipRect(
                  child: Align(
                    heightFactor: 1.0 - _kTearRatio,
                    alignment: Alignment.bottomCenter,
                    child: card(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF080A0D),
      body: AnimatedBuilder(
        animation: Listenable.merge([_tearCtrl, _hintCtrl]),
        builder: (context, _) {
          final t = _tearCtrl.value;
          final torn = t >= 0.99;
          return Stack(
            fit: StackFit.expand,
            children: [
              // ── Navigation-night map background ──────────────────────────
              IgnorePointer(
                child: DeferredMapHost(
                  builder: (_) => MapWidget(
                    styleUri:
                        MapboxResourceUris.navigationNightV1,
                    onMapCreated: _onMapCreated,
                  ),
                ),
              ),

              // ── Dark overlay ─────────────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                color: torn
                    ? AppColors.amber.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.72),
              ),

              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RoadPassHeader(torn: torn),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child: GestureDetector(
                            onHorizontalDragStart:
                                torn ? null : _onDragStart,
                            onHorizontalDragUpdate:
                                torn ? null : _onDragUpdate,
                            onHorizontalDragEnd:
                                torn ? null : _onDragEnd,
                            onHorizontalDragCancel:
                                torn ? null : _onDragCancel,
                            child: _buildTearable(t),
                          ),
                        ),
                      ),
                    ),
                    _RoadStartButton(
                      progress: t,
                      onTap: _startDriveTapHandler(t),
                      bottomPad: mq.padding.bottom,
                    ),
                  ],
                ),
              ),

              if (_hintActive)
                IgnorePointer(
                  child: _RoadHintOverlay(progress: _hintCtrl.value),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hint overlay
// ─────────────────────────────────────────────────────────────────────────────

class _RoadHintOverlay extends StatelessWidget {
  final double progress;
  const _RoadHintOverlay({required this.progress});

  @override
  Widget build(BuildContext context) {
    final alignX = -0.55 + 1.10 * progress;
    final opacity = progress < 0.10
        ? progress / 0.10
        : progress > 0.78
            ? (1.0 - (progress - 0.78) / 0.22).clamp(0.0, 1.0)
            : 1.0;

    return Opacity(
      opacity: opacity,
      child: Align(
        alignment: Alignment(alignX, 0.08),
        child: _RoadHintFinger(progress: progress),
      ),
    );
  }
}

class _RoadHintFinger extends StatelessWidget {
  final double progress;
  const _RoadHintFinger({required this.progress});

  @override
  Widget build(BuildContext context) {
    final arrowOpacity =
        (math.sin(progress * math.pi * 3.5) * 0.5 + 0.5).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: arrowOpacity,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.amber.withValues(alpha: 0.50),
                size: 22,
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.amber.withValues(alpha: 0.90),
                size: 26,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.amber.withValues(alpha: 0.18),
            boxShadow: [
              BoxShadow(
                color: AppColors.amber.withValues(alpha: 0.36),
                blurRadius: 20,
                spreadRadius: 3,
              ),
            ],
          ),
          child: const Icon(
            Icons.touch_app_rounded,
            color: AppColors.amber,
            size: 26,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.amber.withValues(alpha: 0.30),
            ),
          ),
          child: const AppText(
            'SWIPE TO TEAR',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.amber,
            poppins: true,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page header
// ─────────────────────────────────────────────────────────────────────────────

class _RoadPassHeader extends StatelessWidget {
  final bool torn;
  const _RoadPassHeader({required this.torn});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Row(
        children: [
          _HeaderBtn(icon: Icons.arrow_back_rounded, onTap: Get.back),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(
                  'road_trip_title'.tr,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  poppins: true,
                ),
                AppText(
                  torn
                      ? 'road_trip_confirmed'.tr
                      : 'road_trip_swipe'.tr,
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.40),
                  poppins: true,
                ),
              ],
            ),
          ),
          _HeaderBtn(
            icon: torn ? Icons.check_rounded : Icons.refresh_rounded,
            onTap: torn ? null : Get.back,
            dimmed: torn,
          ),
        ],
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool dimmed;
  const _HeaderBtn({required this.icon, this.onTap, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(13),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: dimmed ? 0.22 : 0.68),
          size: 18,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Road trip ticket card
// ─────────────────────────────────────────────────────────────────────────────

class _RoadTicketCard extends StatelessWidget {
  final String fromCity;
  final String toCity;
  final String seatCode;
  final String distanceStr;
  final String durationStr;
  final String dateStr;
  final double perfGlow;

  const _RoadTicketCard({
    required this.fromCity,
    required this.toCity,
    required this.seatCode,
    required this.distanceStr,
    required this.durationStr,
    required this.dateStr,
    this.perfGlow = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141519),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 42,
            offset: const Offset(0, 18),
          ),
          if (perfGlow > 0.01)
            BoxShadow(
              color: AppColors.amber.withValues(alpha: perfGlow * 0.30),
              blurRadius: 32,
              spreadRadius: 4,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Subtle road map background pattern
            Positioned.fill(
              child: CustomPaint(
                painter: _RoadMapPainter(),
                child: const SizedBox.expand(),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RoadTicketInfoSection(
                  fromCity: fromCity,
                  toCity: toCity,
                  seatCode: seatCode,
                  distanceStr: distanceStr,
                  durationStr: durationStr,
                  dateStr: dateStr,
                ),
                _Perforation(glow: perfGlow),
                ColoredBox(
                  color: const Color(0xFF0B0B0E),
                  child: _RoadBarcodeSection(
                    label:
                        '$fromCity · $toCity · $seatCode · ${dateStr.replaceAll('/', ' ')}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Road map background (simplified street-grid decoration)
// ─────────────────────────────────────────────────────────────────────────────

class _RoadMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // Horizontal road lines
    for (var i = 1; i <= 6; i++) {
      final y = h * i / 7;
      canvas.drawLine(Offset(0, y), Offset(w, y), paint);
    }

    // Vertical road lines
    for (var i = 1; i <= 4; i++) {
      final x = w * i / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, h), paint);
    }

    // Diagonal route line (destination path feel)
    final routePaint = Paint()
      ..color = AppColors.amber.withValues(alpha: 0.08)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, h * 0.7), Offset(w, h * 0.15), routePaint);

    // Intersection dots
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    for (var i = 1; i <= 4; i++) {
      for (var j = 1; j <= 6; j++) {
        canvas.drawCircle(
          Offset(w * i / 5, h * j / 7),
          2.5,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RoadMapPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Ticket info section (top ~72%)
// ─────────────────────────────────────────────────────────────────────────────

class _RoadTicketInfoSection extends StatelessWidget {
  final String fromCity;
  final String toCity;
  final String seatCode;
  final String distanceStr;
  final String durationStr;
  final String dateStr;

  const _RoadTicketInfoSection({
    required this.fromCity,
    required this.toCity,
    required this.seatCode,
    required this.distanceStr,
    required this.durationStr,
    required this.dateStr,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // City names — large display (no IATA codes for road trips)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: AppText(
                  fromCity,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  poppins: true,
                  letterSpacing: -1.2,
                  height: 1.0,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: [
                    AppText(
                      durationStr,
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.45),
                      poppins: true,
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      Icons.directions_car_rounded,
                      color: AppColors.amber.withValues(alpha: 0.85),
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 44,
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AppText(
                    toCity,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    poppins: true,
                    letterSpacing: -1.2,
                    height: 1.0,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),

          // Route arrow beneath city names
          Row(
            children: [
              Expanded(
                child: AppText(
                  '↑ FROM',
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.30),
                  poppins: true,
                  letterSpacing: 1.2,
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AppText(
                    'TO ↑',
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.30),
                    poppins: true,
                    letterSpacing: 1.2,
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Stats row 1
          Row(
            children: [
              Expanded(
                child: _StatBlock(
                  label: 'SEAT',
                  value: seatCode,
                  valueColor: AppColors.amber,
                ),
              ),
              Expanded(
                child: _StatBlock(
                  label: 'DISTANCE',
                  value: distanceStr,
                  alignEnd: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Stats row 2
          Row(
            children: [
              Expanded(
                child: _StatBlock(label: 'road_depart'.tr, value: 'road_now'.tr),
              ),
              Expanded(
                child: _StatBlock(
                  label: 'DATE',
                  value: dateStr,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool alignEnd;

  const _StatBlock({
    required this.label,
    required this.value,
    this.valueColor,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final align =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        AppText(
          label,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.30),
          poppins: true,
          letterSpacing: 1.2,
        ),
        const SizedBox(height: 4),
        AppText(
          value,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: valueColor ?? Colors.white.withValues(alpha: 0.88),
          poppins: true,
          letterSpacing: -0.3,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Perforation line
// ─────────────────────────────────────────────────────────────────────────────

class _Perforation extends StatelessWidget {
  final double glow;
  const _Perforation({required this.glow});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: CustomPaint(
        painter: _PerforationPainter(glow: glow),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PerforationPainter extends CustomPainter {
  final double glow;
  _PerforationPainter({required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14 + glow * 0.55)
      ..strokeWidth = 1.0;
    const dashW = 6.0;
    const dashGap = 5.0;
    double x = 18;
    while (x < size.width - 18) {
      canvas.drawLine(Offset(x, cy), Offset(x + dashW, cy), linePaint);
      x += dashW + dashGap;
    }

    if (glow > 0.01) {
      final glowPaint = Paint()
        ..color = AppColors.amber.withValues(alpha: glow * 0.60)
        ..strokeWidth = 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      x = 18;
      while (x < size.width - 18) {
        canvas.drawLine(Offset(x, cy), Offset(x + dashW, cy), glowPaint);
        x += dashW + dashGap;
      }
    }

    final notchPaint = Paint()
      ..color = const Color(0xFF080A0D)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(-2, cy), 11, notchPaint);
    canvas.drawCircle(Offset(size.width + 2, cy), 11, notchPaint);
  }

  @override
  bool shouldRepaint(_PerforationPainter old) => old.glow != glow;
}

// ─────────────────────────────────────────────────────────────────────────────
// Barcode / QR-style section (bottom ~28%)
// ─────────────────────────────────────────────────────────────────────────────

class _RoadBarcodeSection extends StatelessWidget {
  final String label;
  const _RoadBarcodeSection({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      child: Column(
        children: [
          // QR-style pattern (reuses _BarcodePainter visual language)
          Row(
            children: [
              // QR finder squares on left
              _QrFinderBox(),
              const SizedBox(width: 12),
              // Barcode fills the remaining space
              Expanded(
                child: Container(
                  height: 64,
                  clipBehavior: Clip.antiAlias,
                  decoration:
                      BoxDecoration(borderRadius: BorderRadius.circular(3)),
                  child: CustomPaint(
                    painter: _BarcodePainter(),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // QR finder square on right
              _QrFinderBox(),
            ],
          ),
          const SizedBox(height: 10),
          AppText(
            label.toUpperCase(),
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.30),
            poppins: true,
            letterSpacing: 2.0,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _QrFinderBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(42, 42),
      painter: _QrFinderPainter(),
    );
  }
}

class _QrFinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final outerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final innerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.70)
      ..style = PaintingStyle.fill;

    // Outer square
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, s, s),
        const Radius.circular(4),
      ),
      outerPaint,
    );
    // Inner filled square
    final inner = s * 0.35;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          (s - inner) / 2,
          (s - inner) / 2,
          inner,
          inner,
        ),
        const Radius.circular(2),
      ),
      innerPaint,
    );
  }

  @override
  bool shouldRepaint(_QrFinderPainter old) => false;
}

class _BarcodePainter extends CustomPainter {
  static final List<double> _pattern = _buildPattern();

  static List<double> _buildPattern() {
    final rng = math.Random(0x52D19C);
    final list = <double>[];
    double total = 0;
    while (total < 0.97) {
      final bar = rng.nextDouble() * 0.022 + 0.006;
      list.add(bar);
      total += bar;
      if (total >= 0.97) break;
      final gap = rng.nextDouble() * 0.011 + 0.004;
      list.add(-gap);
      total += gap;
    }
    return list;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    double x = 0;
    for (final w in _pattern) {
      final pw = w.abs() * size.width;
      if (w > 0) {
        canvas.drawRect(Rect.fromLTWH(x, 0, pw, size.height), paint);
      }
      x += pw;
      if (x >= size.width) break;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// "Start drive" button
// ─────────────────────────────────────────────────────────────────────────────

class _RoadStartButton extends StatelessWidget {
  final double progress;
  final VoidCallback? onTap;
  final double bottomPad;

  const _RoadStartButton({
    required this.progress,
    required this.onTap,
    required this.bottomPad,
  });

  @override
  Widget build(BuildContext context) {
    final torn = progress >= 0.99;
    final enabled = onTap != null;
    final bgColor =
        Color.lerp(Colors.white, AppColors.amber, progress.clamp(0.0, 1.0))!;
    final textColor =
        torn ? Colors.white.withValues(alpha: 0.95) : const Color(0xFF0A0B0D);

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad + 20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: enabled ? bgColor : bgColor.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(50),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: (progress > 0.15
                              ? AppColors.amber
                              : Colors.white)
                          .withValues(alpha: 0.15),
                      blurRadius: 22,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: torn
                ? [
                    Icon(Icons.check_rounded, color: textColor, size: 18),
                    const SizedBox(width: 8),
                    AppText(
                      'road_drive_started'.tr,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      poppins: true,
                    ),
                  ]
                : [
                    AppText(
                      'road_start_drive'.tr,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      poppins: true,
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: textColor,
                      size: 18,
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}
