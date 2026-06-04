import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../utils/share_utils.dart';

import '../../models/road_trip_session.dart';
import '../../routes/app_routes.dart';
import '../../utils/app_colors.dart';
import '../../utils/flight_route_utils.dart';
import '../../utils/live_flight_progress.dart';
import '../../widgets/common/app_text.dart';

/// Shown when road trip progress reaches 100 %.
class RoadArrivalView extends StatefulWidget {
  const RoadArrivalView({super.key, required this.session});

  final RoadTripSession session;

  @override
  State<RoadArrivalView> createState() => _RoadArrivalViewState();
}

class _RoadArrivalViewState extends State<RoadArrivalView>
    with TickerProviderStateMixin {
  late final AnimationController _sparkleCtrl;
  late final AnimationController _badgeCtrl;
  late final AnimationController _cardCtrl;
  late final AnimationController _btnCtrl;

  RoadTripSession get _s => widget.session;

  @override
  void initState() {
    super.initState();
    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
    _badgeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _cardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _badgeCtrl.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _cardCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _btnCtrl.forward();
    });
  }

  @override
  void dispose() {
    _sparkleCtrl.dispose();
    _badgeCtrl.dispose();
    _cardCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  Widget _stagger(AnimationController ctrl, double start, Widget child) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context2, child2) {
        final raw = ((ctrl.value - start) / (1.0 - start)).clamp(0.0, 1.0);
        final t = Curves.easeOutCubic.transform(raw);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = _s.startedAt;
    final dateStr =
        '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    final driveTime =
        LiveFlightProgress.formatMinutes(_s.totalSeconds / 60.0);
    final distance = FlightRouteUtils.formatDistance(_s.totalKm);

    return Scaffold(
      backgroundColor: AppColors.surf1,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Road-themed gradient background ──────────────────────────────
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.4),
                radius: 1.4,
                colors: [
                  const Color(0xFF1A2535),
                  AppColors.surf1,
                ],
              ),
            ),
          ),
          // ── Amber top glow ────────────────────────────────────────────────
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.3, -0.7),
                radius: 0.85,
                colors: [
                  AppColors.amber.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // ── Road lines (decorative) ───────────────────────────────────────
          const IgnorePointer(child: _RoadDecorPainterWidget()),
          // ── Bottom dark scrim ─────────────────────────────────────────────
          const Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 300,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xF00C0D10)],
                  ),
                ),
              ),
            ),
          ),
          // ── Content ───────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Hero badge
                  AnimatedBuilder(
                    animation: Listenable.merge([_sparkleCtrl, _badgeCtrl]),
                    builder: (context2, child2) {
                      final t = Curves.easeOutBack.transform(
                        _badgeCtrl.value.clamp(0.0, 1.0),
                      );
                      return Opacity(
                        opacity: _badgeCtrl.value.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.55 + 0.45 * t,
                          child: _HeroBadgeSection(
                            sparkleAngle: _sparkleCtrl.value * math.pi * 2,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  // Destination city
                  _stagger(
                    _cardCtrl,
                    0.0,
                    _DestinationTitle(city: _s.toCity),
                  ),

                  const SizedBox(height: 16),

                  // Road trip summary card
                  _stagger(
                    _cardCtrl,
                    0.08,
                    _RoadTripSummaryCard(
                      session: _s,
                      distance: distance,
                      driveTime: driveTime,
                      dateStr: dateStr,
                    ),
                  ),

                  const Spacer(),

                  // Share button
                  _stagger(
                    _btnCtrl,
                    0.0,
                    _ShareButton(
                      session: _s,
                      distance: distance,
                      driveTime: driveTime,
                      dateStr: dateStr,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Home button
                  _stagger(
                    _btnCtrl,
                    0.12,
                    _HomeButton(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Road decorative painter (perspective road lines)
// ─────────────────────────────────────────────────────────────────────────────

class _RoadDecorPainterWidget extends StatelessWidget {
  const _RoadDecorPainterWidget();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _RoadDecorPainter());
  }
}

class _RoadDecorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final vp = Offset(cx, size.height * 0.35); // vanishing point

    // Draw perspective road
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;

    final roadPath = Path()
      ..moveTo(cx - 20, vp.dy)
      ..lineTo(cx + 20, vp.dy)
      ..lineTo(cx + size.width * 0.45, size.height)
      ..lineTo(cx - size.width * 0.45, size.height)
      ..close();
    canvas.drawPath(roadPath, roadPaint);

    // Center dashes (perspective)
    final dashPaint = Paint()
      ..color = AppColors.amber.withValues(alpha: 0.04)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const dashCount = 8;
    for (var i = 0; i < dashCount; i++) {
      final t1 = (i + 0.15) / dashCount;
      final t2 = (i + 0.55) / dashCount;
      final y1 = vp.dy + (size.height - vp.dy) * t1;
      final y2 = vp.dy + (size.height - vp.dy) * t2;
      final x1 = cx + (cx * 0.0) * t1; // stays at center
      final x2 = cx + (cx * 0.0) * t2;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), dashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RoadDecorPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero badge with sparkles
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBadgeSection extends StatelessWidget {
  const _HeroBadgeSection({required this.sparkleAngle});

  final double sparkleAngle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 148,
          height: 148,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(148, 148),
                painter: _SparklePainter(angle: sparkleAngle),
              ),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.amber.withValues(alpha: 0.28),
                      blurRadius: 48,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.amber2, AppColors.amber],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.amber.withValues(alpha: 0.5),
                      blurRadius: 24,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_car_rounded,
                  color: Color(0xFF0A0B0D),
                  size: 36,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppText(
          'ARRIVED',
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.amber,
          letterSpacing: 3.6,
          poppins: true,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        AppText(
          'road_arrival_title'.tr,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.tx2,
          textAlign: TextAlign.center,
          poppins: true,
        ),
      ],
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.angle});

  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const outerCount = 6;
    const innerCount = 5;
    final outerR = size.width * 0.45;
    final innerR = size.width * 0.35;

    void drawSparkle(double x, double y, double sz, double alpha, double rot) {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      canvas.drawPath(
        Path()
          ..moveTo(0, -sz)
          ..lineTo(sz * 0.28, -sz * 0.28)
          ..lineTo(sz, 0)
          ..lineTo(sz * 0.28, sz * 0.28)
          ..lineTo(0, sz)
          ..lineTo(-sz * 0.28, sz * 0.28)
          ..lineTo(-sz, 0)
          ..lineTo(-sz * 0.28, -sz * 0.28)
          ..close(),
        Paint()..color = AppColors.amber.withValues(alpha: alpha),
      );
      canvas.restore();
    }

    for (var i = 0; i < outerCount; i++) {
      final a = angle + i / outerCount * math.pi * 2;
      drawSparkle(cx + outerR * math.cos(a), cy + outerR * math.sin(a),
          4.8, 0.82, a + math.pi / 4);
    }
    for (var i = 0; i < innerCount; i++) {
      final a = -angle * 0.65 + i / innerCount * math.pi * 2;
      drawSparkle(cx + innerR * math.cos(a), cy + innerR * math.sin(a),
          3.0, 0.50, a);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.angle != angle;
}

// ─────────────────────────────────────────────────────────────────────────────
// Destination city title
// ─────────────────────────────────────────────────────────────────────────────

class _DestinationTitle extends StatelessWidget {
  const _DestinationTitle({required this.city});

  final String city;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Colors.white, Color(0xFFE8EAED)],
      ).createShader(bounds),
      child: AppText(
        city,
        fontSize: 40,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        poppins: true,
        height: 1.05,
        textAlign: TextAlign.center,
        maxLines: 2,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Road trip summary card
// ─────────────────────────────────────────────────────────────────────────────

class _RoadTripSummaryCard extends StatelessWidget {
  const _RoadTripSummaryCard({
    required this.session,
    required this.distance,
    required this.driveTime,
    required this.dateStr,
  });

  final RoadTripSession session;
  final String distance;
  final String driveTime;
  final String dateStr;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.hair2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.amberSoft,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: AppColors.amber.withValues(alpha: 0.35),
                        ),
                      ),
                      child: AppText(
                        'ROAD TRIP',
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: AppColors.amber,
                        letterSpacing: 1.4,
                        poppins: true,
                      ),
                    ),
                    const Spacer(),
                    AppText(
                      dateStr,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.tx3,
                      poppins: true,
                    ),
                  ],
                ),
              ),

              Container(height: 1, color: AppColors.hair),

              // Route
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            session.fromCity,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.tx1,
                            poppins: true,
                            height: 1.1,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 2),
                          AppText(
                            session.fromCountry,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.tx3,
                            poppins: true,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        children: [
                          Icon(
                            Icons.directions_car_rounded,
                            size: 18,
                            color: AppColors.amber.withValues(alpha: 0.9),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 40,
                            child: CustomPaint(
                              size: const Size(40, 2),
                              painter: _GradientLinePainter(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AppText(
                            session.toCity,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.amber,
                            poppins: true,
                            height: 1.1,
                            maxLines: 1,
                            textAlign: TextAlign.end,
                          ),
                          const SizedBox(height: 2),
                          AppText(
                            session.toCountry,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.tx3,
                            poppins: true,
                            maxLines: 1,
                            textAlign: TextAlign.end,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Perforated divider
              SizedBox(
                height: 14,
                child: CustomPaint(
                  painter: _PerforatedLinePainter(),
                  size: const Size.fromHeight(14),
                ),
              ),

              // Stats
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: Icons.route_rounded,
                        label: 'DISTANCE',
                        value: distance,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 42,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.timer_outlined,
                        label: 'DRIVE TIME',
                        value: driveTime,
                        mono: true,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 42,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.event_seat_outlined,
                        label: 'SEAT',
                        value: session.seatCode,
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

class _GradientLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.08),
            AppColors.amber.withValues(alpha: 0.65),
            Colors.white.withValues(alpha: 0.08),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _GradientLinePainter old) => false;
}

class _PerforatedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashW = 5.0;
    const gap = 4.5;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    var x = 14.0;
    final y = size.height / 2;
    while (x < size.width - 14) {
      canvas.drawLine(Offset(x, y), Offset(x + dashW, y), paint);
      x += dashW + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _PerforatedLinePainter old) => false;
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.amber.withValues(alpha: 0.82)),
        const SizedBox(height: 5),
        AppText(
          label,
          fontSize: 7.5,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.35),
          letterSpacing: 0.8,
          poppins: true,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        AppText(
          value,
          fontSize: mono ? 12 : 13,
          fontWeight: FontWeight.w700,
          color: AppColors.tx1,
          poppins: !mono,
          mono: mono,
          textAlign: TextAlign.center,
          maxLines: 1,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action buttons
// ─────────────────────────────────────────────────────────────────────────────

class _ShareButton extends StatelessWidget {
  const _ShareButton({
    required this.session,
    required this.distance,
    required this.driveTime,
    required this.dateStr,
  });

  final RoadTripSession session;
  final String distance;
  final String driveTime;
  final String dateStr;

  String get _shareText =>
      '🚗 Road Trip Complete!\n\n'
      '${session.fromCity} → ${session.toCity}\n'
      '💺 Seat ${session.seatCode}  ·  📏 $distance  ·  ⏱ $driveTime\n'
      '📅 $dateStr\n\n'
      'Focused the whole drive ✨\n#FoFuckDingo #RoadTrip';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.transparent,
            child: Builder(
              builder: (anchorContext) => InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ShareUtils.shareText(anchorContext, _shareText);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.ios_share_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 10),
                    AppText(
                      'road_share_friends'.tr,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.85),
                      poppins: true,
                    ),
                  ],
                ),
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [AppColors.amber2, AppColors.amber],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.amber.withValues(alpha: 0.38),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              Get.offAllNamed(AppRoutes.home);
            },
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 17),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home_rounded, size: 20, color: Color(0xFF0A0B0D)),
                  SizedBox(width: 10),
                  AppText(
                    'road_back_home'.tr,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0A0B0D),
                    poppins: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
