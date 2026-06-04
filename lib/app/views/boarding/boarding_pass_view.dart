import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../../config/api_urls.dart';
import '../../models/live_flight_session.dart';
import '../../utils/app_colors.dart';
import '../../utils/flight_route_utils.dart';
import '../../widgets/common/app_text.dart';
import '../../widgets/map/deferred_map_host.dart';
import '../live/live_flight_view.dart';

const double _kTearRatio = 0.72;
const double _kMaxDragPx = 260.0;
const double _kSnapThreshold = 0.48;

// ─────────────────────────────────────────────────────────────────────────────
// Entry
// ─────────────────────────────────────────────────────────────────────────────

class BoardingPassView extends StatefulWidget {
  final String fromCode;
  final String fromCity;
  final String toCode;
  final String toCity;
  final String seatCode;
  final double distanceKm;
  final Duration flightDuration;
  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;

  const BoardingPassView({
    super.key,
    required this.fromCode,
    required this.fromCity,
    required this.toCode,
    required this.toCity,
    required this.seatCode,
    required this.distanceKm,
    required this.flightDuration,
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
  });

  @override
  State<BoardingPassView> createState() => _BoardingPassState();
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class _BoardingPassState extends State<BoardingPassView>
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
    _durationStr = FlightRouteUtils.formatDurationCompact(widget.flightDuration);
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
      final span =
          math.max((fl - tl).abs(), (flng - tlng).abs());
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
        pitch: 35.0,
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
      final session = LiveFlightSession.fromBoarding(
        fromCode: widget.fromCode,
        fromCity: widget.fromCity,
        toCode: widget.toCode,
        toCity: widget.toCity,
        seatCode: widget.seatCode,
        distanceKm: widget.distanceKm,
        flightDuration: widget.flightDuration,
        fromLat: widget.fromLat,
        fromLng: widget.fromLng,
        toLat: widget.toLat,
        toLng: widget.toLng,
      );
      Get.off(() => LiveFlightView(session: session));
    });
  }

  VoidCallback? _checkInTapHandler(double t) {
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

    Widget card({double glow = 0.0}) => _TicketCard(
          fromCode: widget.fromCode,
          fromCity: widget.fromCity,
          toCode: widget.toCode,
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

    // Gentle peel: linear mapping keeps drag 1:1 with movement.
    // Small angle so the piece droops naturally rather than swinging rigidly.
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

        // Bottom portion (barcode) — peels away from the perforation line.
        // Rotation pivot = top-center of this piece = the tear edge.
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
              // ── Satellite map background ─────────────────────────────
              IgnorePointer(
                child: DeferredMapHost(
                  builder: (_) => MapWidget(
                    styleUri: MapboxResourceUris.satelliteStreetsV12,
                    onMapCreated: _onMapCreated,
                  ),
                ),
              ),

              // ── Dark overlay — fades to amber glow on completion ─────
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
                    _PageHeader(torn: torn),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: GestureDetector(
                            onHorizontalDragStart: torn ? null : _onDragStart,
                            onHorizontalDragUpdate: torn ? null : _onDragUpdate,
                            onHorizontalDragEnd: torn ? null : _onDragEnd,
                            onHorizontalDragCancel: torn ? null : _onDragCancel,
                            child: _buildTearable(t),
                          ),
                        ),
                      ),
                    ),
                    _CheckInButton(
                      progress: t,
                      onTap: _checkInTapHandler(t),
                      bottomPad: mq.padding.bottom,
                    ),
                  ],
                ),
              ),
              if (_hintActive)
                IgnorePointer(
                  child: _HintOverlay(progress: _hintCtrl.value),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hint overlay — swipe-up finger animation
// ─────────────────────────────────────────────────────────────────────────────

class _HintOverlay extends StatelessWidget {
  final double progress;
  const _HintOverlay({required this.progress});

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
        child: _HintFinger(progress: progress),
      ),
    );
  }
}

class _HintFinger extends StatelessWidget {
  final double progress;
  const _HintFinger({required this.progress});

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
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final bool torn;
  const _PageHeader({required this.torn});

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
                  'boarding_check_in'.tr,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  poppins: true,
                ),
                AppText(
                  torn ? 'boarding_confirmed'.tr : 'boarding_swipe'.tr,
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
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
// Boarding ticket card
// ─────────────────────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  final String fromCode, fromCity, toCode, toCity, seatCode;
  final String distanceStr, durationStr, dateStr;
  final double perfGlow;

  const _TicketCard({
    required this.fromCode,
    required this.fromCity,
    required this.toCode,
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
            Positioned.fill(
              child: CustomPaint(
                painter: _WorldMapPainter(),
                child: const SizedBox.expand(),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TicketInfoSection(
                  fromCode: fromCode,
                  fromCity: fromCity,
                  toCode: toCode,
                  toCity: toCity,
                  seatCode: seatCode,
                  distanceStr: distanceStr,
                  durationStr: durationStr,
                  dateStr: dateStr,
                ),
                _Perforation(glow: perfGlow),
                ColoredBox(
                  color: const Color(0xFF0B0B0E),
                  child: _BarcodeSection(
                    barcodeLabel:
                        '$fromCode $toCode $seatCode · ${dateStr.replaceAll('/', ' ')}',
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
// World map background painter
// ─────────────────────────────────────────────────────────────────────────────

class _WorldMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.11)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    for (final pts in _continents) {
      final path = Path();
      path.moveTo(pts[0][0] * size.width, pts[0][1] * size.height);
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i][0] * size.width, pts[i][1] * size.height);
      }
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  // Normalized (x, y) continent outlines — equirectangular projection.
  // x: 0 = 180°W → 1 = 180°E   |   y: 0 = 90°N → 1 = 90°S
  static const List<List<List<double>>> _continents = [
    // Greenland
    [
      [0.27, 0.03], [0.35, 0.01], [0.39, 0.04], [0.38, 0.12],
      [0.34, 0.17], [0.28, 0.17], [0.24, 0.12], [0.24, 0.06],
    ],
    // North America
    [
      [0.04, 0.14], [0.10, 0.10], [0.20, 0.10], [0.31, 0.11],
      [0.34, 0.24], [0.31, 0.36], [0.28, 0.42], [0.26, 0.46],
      [0.20, 0.45], [0.16, 0.38], [0.14, 0.33], [0.08, 0.28],
      [0.06, 0.22],
    ],
    // South America
    [
      [0.26, 0.46], [0.33, 0.43], [0.38, 0.52], [0.38, 0.63],
      [0.34, 0.72], [0.32, 0.82], [0.28, 0.93], [0.23, 0.94],
      [0.21, 0.88], [0.19, 0.78], [0.19, 0.62], [0.20, 0.52],
    ],
    // Europe
    [
      [0.47, 0.07], [0.52, 0.07], [0.57, 0.12], [0.59, 0.20],
      [0.57, 0.27], [0.54, 0.33], [0.52, 0.38], [0.50, 0.40],
      [0.47, 0.38], [0.44, 0.36], [0.43, 0.30], [0.44, 0.22],
      [0.45, 0.15],
    ],
    // Africa
    [
      [0.45, 0.32], [0.50, 0.28], [0.58, 0.28], [0.64, 0.34],
      [0.65, 0.46], [0.63, 0.58], [0.60, 0.70], [0.56, 0.83],
      [0.52, 0.91], [0.48, 0.90], [0.46, 0.82], [0.44, 0.72],
      [0.44, 0.60], [0.46, 0.48], [0.44, 0.40],
    ],
    // Asia (mainland)
    [
      [0.57, 0.20], [0.62, 0.14], [0.72, 0.09], [0.82, 0.06],
      [0.96, 0.10], [0.98, 0.20], [0.96, 0.28], [0.93, 0.34],
      [0.91, 0.44], [0.88, 0.52], [0.86, 0.58], [0.83, 0.60],
      [0.78, 0.56], [0.74, 0.56], [0.71, 0.57], [0.69, 0.46],
      [0.67, 0.36], [0.65, 0.34], [0.62, 0.28], [0.59, 0.28],
    ],
    // Australia
    [
      [0.80, 0.62], [0.87, 0.58], [0.94, 0.63], [0.97, 0.70],
      [0.97, 0.78], [0.94, 0.86], [0.88, 0.88], [0.82, 0.86],
      [0.79, 0.80], [0.79, 0.70],
    ],
  ];

  @override
  bool shouldRepaint(_WorldMapPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Info section (top ~72 % of the ticket)
// ─────────────────────────────────────────────────────────────────────────────

class _TicketInfoSection extends StatelessWidget {
  final String fromCode, fromCity, toCode, toCity, seatCode;
  final String distanceStr, durationStr, dateStr;

  const _TicketInfoSection({
    required this.fromCode,
    required this.fromCity,
    required this.toCode,
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
          // IATA codes
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: AppText(
                  fromCode,
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  poppins: true,
                  letterSpacing: -1.5,
                  height: 1.0,
                ),
              ),
              Column(
                children: [
                  AppText(
                    durationStr,
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.45),
                    poppins: true,
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.flight_rounded,
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
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AppText(
                    toCode,
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    poppins: true,
                    letterSpacing: -1.5,
                    height: 1.0,
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
            ],
          ),

          // City names
          Row(
            children: [
              Expanded(
                child: AppText(
                  fromCity,
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.38),
                  poppins: true,
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AppText(
                    toCity,
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.38),
                    poppins: true,
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
                child: _StatBlock(
                  label: 'boarding_stat_boarding'.tr,
                  value: 'road_now'.tr,
                ),
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
// Perforation line — dashes + amber glow on tear
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
// Barcode section (bottom ~28 % of the ticket)
// ─────────────────────────────────────────────────────────────────────────────

class _BarcodeSection extends StatelessWidget {
  final String barcodeLabel;
  const _BarcodeSection({required this.barcodeLabel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      child: Column(
        children: [
          Container(
            height: 64,
            clipBehavior: Clip.antiAlias,
            decoration:
                BoxDecoration(borderRadius: BorderRadius.circular(3)),
            child: CustomPaint(
              painter: _BarcodePainter(),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 10),
          AppText(
            barcodeLabel.toUpperCase(),
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

class _BarcodePainter extends CustomPainter {
  static final List<double> _pattern = _buildPattern();

  static List<double> _buildPattern() {
    final rng = math.Random(0x4F3A7B);
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
// "Check in" / "Confirmed!" button
// ─────────────────────────────────────────────────────────────────────────────

class _CheckInButton extends StatelessWidget {
  final double progress;
  final VoidCallback? onTap;
  final double bottomPad;

  const _CheckInButton({
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
                      color:
                          (progress > 0.15 ? AppColors.amber : Colors.white)
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
                      'boarding_confirmed_short'.tr,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      poppins: true,
                    ),
                  ]
                : [
                    AppText(
                      'boarding_check_in'.tr,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      poppins: true,
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded,
                        color: textColor, size: 18),
                  ],
          ),
        ),
      ),
    );
  }
}
