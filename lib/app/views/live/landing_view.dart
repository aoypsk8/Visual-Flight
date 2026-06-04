import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../utils/share_utils.dart';

import '../../models/live_flight_session.dart';
import '../../routes/app_routes.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_locale_utils.dart';
import '../../utils/app_resources.dart';
import '../../utils/flight_route_utils.dart';
import '../../utils/live_flight_progress.dart';
import '../../widgets/common/app_text.dart';

/// Shown when live flight progress reaches 100%.
class LandingView extends StatefulWidget {
  const LandingView({super.key, required this.session});

  final LiveFlightSession session;

  @override
  State<LandingView> createState() => _LandingViewState();
}

class _LandingViewState extends State<LandingView>
    with TickerProviderStateMixin {
  late final AnimationController _sparkleCtrl;
  late final AnimationController _badgeCtrl;
  late final AnimationController _cardCtrl;
  late final AnimationController _btnCtrl;

  LiveFlightSession get _s => widget.session;

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
    final isLao = isLaoLocale(context);
    final date = _s.startedAt;
    final dateStr =
        '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    final focusTime =
        LiveFlightProgress.formatMinutes(_s.totalSeconds / 60.0);
    final distance = FlightRouteUtils.formatDistance(_s.totalKm);

    return Scaffold(
      backgroundColor: AppColors.surf1,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background photo ──────────────────────────────────────────────
          Image.asset(
            AppUiAssets.finishedFlight,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.15),
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: AppColors.surf1),
          ),
          // ── Dark scrim ────────────────────────────────────────────────────
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.38, 1.0],
                colors: [
                  Color(0x88000000),
                  Color(0x33000000),
                  Color(0xF50C0D10),
                ],
              ),
            ),
          ),
          // ── Amber radial glow (top-right) ─────────────────────────────────
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.45, -0.62),
                radius: 0.88,
                colors: [
                  AppColors.amber.withValues(alpha: 0.17),
                  Colors.transparent,
                ],
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
                            isLao: isLao,
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

                  // Boarding-pass card
                  _stagger(
                    _cardCtrl,
                    0.08,
                    _BoardingPassCard(
                      session: _s,
                      distance: distance,
                      focusTime: focusTime,
                      dateStr: dateStr,
                      isLao: isLao,
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
                      focusTime: focusTime,
                      dateStr: dateStr,
                      isLao: isLao,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Home button
                  _stagger(
                    _btnCtrl,
                    0.12,
                    _HomeButton(isLao: isLao),
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
// Hero badge + sparkle ring
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBadgeSection extends StatelessWidget {
  const _HeroBadgeSection({
    required this.sparkleAngle,
    required this.isLao,
  });

  final double sparkleAngle;
  final bool isLao;

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
              // Sparkle ring
              CustomPaint(
                size: const Size(148, 148),
                painter: _SparklePainter(angle: sparkleAngle),
              ),
              // Outer amber pulse halo
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
              // Badge circle
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
                  Icons.flight_land_rounded,
                  color: Color(0xFF0A0B0D),
                  size: 36,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppText(
          'LANDED',
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.amber,
          letterSpacing: 3.6,
          poppins: true,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        AppText(
          'landing_touchdown'.tr,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.tx2,
          textAlign: TextAlign.center,
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

    // Two rings: outer (6 sparkles, clockwise) + inner (5 sparkles, counter)
    const outerCount = 6;
    const innerCount = 5;
    final outerR = size.width * 0.45;
    final innerR = size.width * 0.35;

    void drawSparkle(
        double x, double y, double sz, double alpha, double rotation) {
      final paint = Paint()
        ..color = AppColors.amber.withValues(alpha: alpha);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      final path = Path()
        ..moveTo(0, -sz)
        ..lineTo(sz * 0.28, -sz * 0.28)
        ..lineTo(sz, 0)
        ..lineTo(sz * 0.28, sz * 0.28)
        ..lineTo(0, sz)
        ..lineTo(-sz * 0.28, sz * 0.28)
        ..lineTo(-sz, 0)
        ..lineTo(-sz * 0.28, -sz * 0.28)
        ..close();
      canvas.drawPath(path, paint);
      canvas.restore();
    }

    for (var i = 0; i < outerCount; i++) {
      final a = angle + i / outerCount * math.pi * 2;
      drawSparkle(
        cx + outerR * math.cos(a),
        cy + outerR * math.sin(a),
        4.8,
        0.82,
        a + math.pi / 4,
      );
    }
    for (var i = 0; i < innerCount; i++) {
      final a = -angle * 0.65 + i / innerCount * math.pi * 2;
      drawSparkle(
        cx + innerR * math.cos(a),
        cy + innerR * math.sin(a),
        3.0,
        0.50,
        a,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.angle != angle;
}

// ─────────────────────────────────────────────────────────────────────────────
// Destination city
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
// Boarding-pass card
// ─────────────────────────────────────────────────────────────────────────────

class _BoardingPassCard extends StatelessWidget {
  const _BoardingPassCard({
    required this.session,
    required this.distance,
    required this.focusTime,
    required this.dateStr,
    required this.isLao,
  });

  final LiveFlightSession session;
  final String distance;
  final String focusTime;
  final String dateStr;
  final bool isLao;

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
              // ── Header row ──────────────────────────────────────────────
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
                        'BOARDING PASS',
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

              // ── Hairline ─────────────────────────────────────────────────
              Container(height: 1, color: AppColors.hair),

              // ── Route section ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Origin
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            session.fromCode,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppColors.tx1,
                            poppins: true,
                            height: 1.0,
                          ),
                          const SizedBox(height: 3),
                          AppText(
                            session.fromCity,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.tx3,
                            poppins: true,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),

                    // Route arrow
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.flight_rounded,
                            size: 20,
                            color: AppColors.amber.withValues(alpha: 0.9),
                          ),
                          const SizedBox(height: 5),
                          SizedBox(
                            width: 48,
                            child: CustomPaint(
                              size: const Size(48, 2),
                              painter: _GradientLinePainter(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Destination
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AppText(
                            session.toCode,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppColors.amber,
                            poppins: true,
                            height: 1.0,
                          ),
                          const SizedBox(height: 3),
                          AppText(
                            session.toCity,
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

              // ── Perforated divider ────────────────────────────────────────
              SizedBox(
                height: 16,
                child: CustomPaint(
                  painter: _PerforatedDividerPainter(),
                  size: const Size.fromHeight(16),
                ),
              ),

              // ── Stats row ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: Icons.straighten_rounded,
                        label: 'landing_stat_distance'.tr,
                        value: distance,
                      ),
                    ),
                    _vDivider(),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.timer_outlined,
                        label: 'landing_stat_focus'.tr,
                        value: focusTime,
                        mono: true,
                      ),
                    ),
                    _vDivider(),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.event_seat_outlined,
                        label: 'landing_stat_seat'.tr,
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

  Widget _vDivider() => Container(
        width: 1,
        height: 42,
        color: Colors.white.withValues(alpha: 0.1),
      );
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

class _PerforatedDividerPainter extends CustomPainter {
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
  bool shouldRepaint(covariant _PerforatedDividerPainter old) => false;
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
    required this.focusTime,
    required this.dateStr,
    required this.isLao,
  });

  final LiveFlightSession session;
  final String distance;
  final String focusTime;
  final String dateStr;
  final bool isLao;

  String get _shareText {
    final from = '${session.fromCode} (${session.fromCity})';
    final to = '${session.toCode} (${session.toCity})';
    return isLao
        ? '✈️ ສຳເລັດການບິນ!\n\n$from → $to\n💺 ທີ່ນັ່ງ ${session.seatCode}  ·  📏 $distance  ·  ⏱ $focusTime\n📅 $dateStr\n\nໂຟກັດຕັ້ງແຕ່離陸ຈົນລົງຈອດດ້ວຍ FoFuckDingo ✨'
        : '✈️ FoFuckDingo Complete!\n\n$from → $to\n💺 Seat ${session.seatCode}  ·  📏 $distance  ·  ⏱ $focusTime\n📅 $dateStr\n\nStayed focused from takeoff to landing ✨\n#FoFuckDingo';
  }

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
                      'landing_share'.tr,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.85),
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
  const _HomeButton({required this.isLao});

  final bool isLao;

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
                  const Icon(
                    Icons.home_rounded,
                    size: 20,
                    color: Color(0xFF0A0B0D),
                  ),
                  const SizedBox(width: 10),
                  AppText(
                    'landing_back_home'.tr,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0A0B0D),
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
