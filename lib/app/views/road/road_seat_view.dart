import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_theme.dart';
import '../../utils/flight_route_utils.dart';
import '../../widgets/common/app_text.dart';
import 'road_trip_pass_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Seat model
// ─────────────────────────────────────────────────────────────────────────────

enum _CarSeatId { drv, fp, rl, rc, rr }

extension _CarSeatIdLabel on _CarSeatId {
  String get code {
    switch (this) {
      case _CarSeatId.drv:
        return 'DRV';
      case _CarSeatId.fp:
        return 'FP';
      case _CarSeatId.rl:
        return 'RL';
      case _CarSeatId.rc:
        return 'RC';
      case _CarSeatId.rr:
        return 'RR';
    }
  }

  String get fullLabel {
    switch (this) {
      case _CarSeatId.drv:
        return 'Driver';
      case _CarSeatId.fp:
        return 'Front Passenger';
      case _CarSeatId.rl:
        return 'Rear Left';
      case _CarSeatId.rc:
        return 'Rear Center';
      case _CarSeatId.rr:
        return 'Rear Right';
    }
  }

  String get rowLabel {
    switch (this) {
      case _CarSeatId.drv:
      case _CarSeatId.fp:
        return 'Front cabin';
      case _CarSeatId.rl:
      case _CarSeatId.rc:
      case _CarSeatId.rr:
        return 'Rear cabin';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Car body painter (top-down silhouette)
// ─────────────────────────────────────────────────────────────────────────────

class _CarBodyPainter extends CustomPainter {
  const _CarBodyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Outer body ───────────────────────────────────────────────────────────
    final bodyPath = Path()
      ..moveTo(w * 0.50, 0)
      ..cubicTo(w * 0.90, 2, w, h * 0.08, w, h * 0.18)
      ..lineTo(w, h * 0.82)
      ..cubicTo(w, h * 0.92, w * 0.88, h, w * 0.72, h)
      ..lineTo(w * 0.28, h)
      ..cubicTo(w * 0.12, h, 0, h * 0.92, 0, h * 0.82)
      ..lineTo(0, h * 0.18)
      ..cubicTo(0, h * 0.08, w * 0.10, 2, w * 0.50, 0)
      ..close();

    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = const Color(0xFF1A1E28)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = const Color(0xFF4A5260).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // ── Windshield (front glass) ─────────────────────────────────────────────
    final frontGlass = Path()
      ..moveTo(w * 0.22, h * 0.06)
      ..cubicTo(w * 0.50, h * 0.01, w * 0.78, h * 0.06, w * 0.78, h * 0.06)
      ..lineTo(w * 0.72, h * 0.17)
      ..cubicTo(w * 0.50, h * 0.13, w * 0.28, h * 0.17, w * 0.28, h * 0.17)
      ..close();

    canvas.drawPath(
      frontGlass,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6A8FA8), Color(0xFF3D5A72)],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.2)),
    );
    canvas.drawPath(
      frontGlass,
      Paint()
        ..color = const Color(0xFF5C7888)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Windshield center divider
    canvas.drawLine(
      Offset(w * 0.50, h * 0.02),
      Offset(w * 0.50, h * 0.16),
      Paint()
        ..color = const Color(0xFF2A3A4A)
        ..strokeWidth = 1.5,
    );

    // ── Rear window ──────────────────────────────────────────────────────────
    final rearGlass = Path()
      ..moveTo(w * 0.25, h * 0.83)
      ..lineTo(w * 0.29, h * 0.93)
      ..cubicTo(w * 0.50, h * 0.97, w * 0.71, h * 0.93, w * 0.71, h * 0.93)
      ..lineTo(w * 0.75, h * 0.83)
      ..cubicTo(w * 0.50, h * 0.88, w * 0.25, h * 0.83, w * 0.25, h * 0.83)
      ..close();

    canvas.drawPath(
      rearGlass,
      Paint()
        ..color = const Color(0xFF3D5A72).withValues(alpha: 0.75),
    );
    canvas.drawPath(
      rearGlass,
      Paint()
        ..color = const Color(0xFF5C7888)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // ── Side windows (left) ──────────────────────────────────────────────────
    _drawSideWindow(
      canvas,
      Rect.fromLTWH(w * 0.04, h * 0.20, w * 0.08, h * 0.24),
    );
    _drawSideWindow(
      canvas,
      Rect.fromLTWH(w * 0.04, h * 0.50, w * 0.08, h * 0.22),
    );

    // ── Side windows (right) ─────────────────────────────────────────────────
    _drawSideWindow(
      canvas,
      Rect.fromLTWH(w * 0.88, h * 0.20, w * 0.08, h * 0.24),
    );
    _drawSideWindow(
      canvas,
      Rect.fromLTWH(w * 0.88, h * 0.50, w * 0.08, h * 0.22),
    );

    // ── Center console strip ─────────────────────────────────────────────────
    final consoleRect =
        RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.42, h * 0.24, w * 0.16, h * 0.46),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      consoleRect,
      Paint()..color = const Color(0xFF23282F),
    );
    canvas.drawRRect(
      consoleRect,
      Paint()
        ..color = const Color(0xFF3A404C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // ── Steering wheel ───────────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(w * 0.28, h * 0.30),
      w * 0.065,
      Paint()..color = const Color(0xFF2C3240),
    );
    canvas.drawCircle(
      Offset(w * 0.28, h * 0.30),
      w * 0.065,
      Paint()
        ..color = const Color(0xFF4A5268)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    canvas.drawCircle(
      Offset(w * 0.28, h * 0.30),
      w * 0.018,
      Paint()..color = const Color(0xFF3A404C),
    );
  }

  void _drawSideWindow(Canvas canvas, Rect rect) {
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(
      rRect,
      Paint()..color = const Color(0xFF3D5A72).withValues(alpha: 0.65),
    );
    canvas.drawRRect(
      rRect,
      Paint()
        ..color = const Color(0xFF5C7888)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _CarBodyPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Windshield / cockpit decoration (equivalent of _CockpitDecor)
// ─────────────────────────────────────────────────────────────────────────────

class _FrontHoodDecor extends StatelessWidget {
  const _FrontHoodDecor();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            top: 8,
            left: 32,
            right: 32,
            height: 60,
            child: CustomPaint(
              painter: _WindshieldPainter(),
            ),
          ),
          Positioned(
            bottom: 10,
            child: AppText(
              'Front hood',
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.32),
              letterSpacing: 1.4,
              poppins: true,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 32,
            right: 32,
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _WindshieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final glass = Path()
      ..moveTo(w * 0.14, h)
      ..cubicTo(w * 0.50, h * 0.04, w * 0.86, h, w * 0.86, h)
      ..lineTo(w * 0.78, h * 0.58)
      ..cubicTo(w * 0.50, h * 0.42, w * 0.22, h * 0.58, w * 0.22, h * 0.58)
      ..close();

    canvas.drawPath(
      glass,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7A8FA8), Color(0xFF3D4A5C)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      glass,
      Paint()
        ..color = const Color(0xFF5C6678)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Center divider
    canvas.drawLine(
      Offset(w * 0.50, h * 0.14),
      Offset(w * 0.50, h * 0.95),
      Paint()
        ..color = const Color(0xFF2A3140)
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual car seat tile
// ─────────────────────────────────────────────────────────────────────────────

const _kCarSeatW = 72.0;
const _kCarSeatH = 56.0;

class _CarSeatTile extends StatelessWidget {
  final _CarSeatId seat;
  final bool isSelected;
  final VoidCallback onTap;

  const _CarSeatTile({
    required this.seat,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final Color fill;
    final Border? border;
    final List<BoxShadow>? shadows;

    if (isSelected) {
      fill = AppColors.amber;
      shadows = [
        BoxShadow(
          color: AppColors.amber.withValues(alpha: 0.48),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
      border = null;
    } else {
      fill = colors.card;
      border = Border.all(color: colors.hair2, width: 1.2);
      shadows = null;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: _kCarSeatW,
        height: _kCarSeatH,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(6),
          ),
          border: border,
          boxShadow: shadows,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Headrest bar at top
            Positioned(
              top: 7,
              left: 10,
              right: 10,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0A0B0D).withValues(alpha: 0.28)
                      : colors.hair2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Seat code label
            if (isSelected)
              Icon(
                Icons.directions_car_rounded,
                size: 20,
                color: const Color(0xFF0A0B0D),
              )
            else
              AppText(
                seat.code,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.78),
                poppins: true,
                letterSpacing: 0.5,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Row divider (Galley equivalent)
// ─────────────────────────────────────────────────────────────────────────────

class _RearCabinDivider extends StatelessWidget {
  const _RearCabinDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.airline_seat_recline_normal_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.38),
                ),
                const SizedBox(width: 6),
                AppText(
                  'Rear cabin',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.42),
                  poppins: true,
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Car diagram body — the full top-down car with seats
// ─────────────────────────────────────────────────────────────────────────────

class _CarDiagram extends StatelessWidget {
  final _CarSeatId? selected;
  final ValueChanged<_CarSeatId> onSeatTap;

  const _CarDiagram({
    required this.selected,
    required this.onSeatTap,
  });

  Widget _seat(_CarSeatId id) => _CarSeatTile(
        seat: id,
        isSelected: selected == id,
        onTap: () => onSeatTap(id),
      );

  @override
  Widget build(BuildContext context) {
    const carW = 280.0;
    const carH = 480.0;
    const seatAreaPadH = 14.0;

    return SizedBox(
      width: carW,
      height: carH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Car body background
          CustomPaint(
            painter: const _CarBodyPainter(),
            child: const SizedBox.expand(),
          ),

          // Seats layout overlay
          Column(
            children: [
              // Front hood / windshield area
              const _FrontHoodDecor(),

              // Front row (DRV left, center console gap, FP right)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: seatAreaPadH,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _seat(_CarSeatId.drv),
                    // Center console placeholder
                    SizedBox(
                      width: _kCarSeatW * 0.55,
                      height: _kCarSeatH,
                      child: Center(
                        child: Container(
                          width: 24,
                          height: _kCarSeatH * 0.7,
                          decoration: BoxDecoration(
                            color: const Color(0xFF23282F),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _seat(_CarSeatId.fp),
                  ],
                ),
              ),

              const _RearCabinDivider(),

              const SizedBox(height: seatAreaPadH),

              // Rear row (RL, RC, RR)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _seat(_CarSeatId.rl),
                    _seat(_CarSeatId.rc),
                    _seat(_CarSeatId.rr),
                  ],
                ),
              ),

              // Remaining space (trunk area)
              const Spacer(),
              Icon(
                Icons.directions_car_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.18),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _RoadSeatHeader extends StatelessWidget {
  const _RoadSeatHeader({
    required this.fromCity,
    required this.fromCountry,
    required this.toCity,
    required this.toCountry,
    required this.topPad,
    this.distanceKm,
    this.duration,
  });

  final String fromCity;
  final String fromCountry;
  final String toCity;
  final String toCountry;
  final double topPad;
  final double? distanceKm;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasMeta = distanceKm != null && duration != null;
    final metaLabel = hasMeta
        ? '${FlightRouteUtils.formatDistance(distanceKm!)} · '
            '${FlightRouteUtils.formatDurationCompact(duration!)}'
        : null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F12).withValues(alpha: 0.90),
        border: Border(bottom: BorderSide(color: colors.hair)),
      ),
      padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: Get.back,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.surf2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.hair),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: colors.tx2,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'Your trip',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.tx3,
                  letterSpacing: 0.6,
                  poppins: true,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.directions_car_rounded,
                      size: 20,
                      color: AppColors.amber.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppText(
                        '$fromCity → $toCity',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        poppins: true,
                        letterSpacing: -0.4,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (metaLabel != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: AppText(
                          metaLabel,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.62),
                          poppins: true,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                AppText(
                  '$fromCountry → $toCountry',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.tx3,
                  poppins: true,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seat info card (bottom panel detail)
// ─────────────────────────────────────────────────────────────────────────────

class _CarSeatInfoCard extends StatelessWidget {
  final _CarSeatId seat;
  const _CarSeatInfoCard({required this.seat});

  IconData get _icon {
    switch (seat) {
      case _CarSeatId.drv:
        return Icons.directions_car_rounded;
      case _CarSeatId.fp:
        return Icons.person_rounded;
      case _CarSeatId.rl:
      case _CarSeatId.rc:
      case _CarSeatId.rr:
        return Icons.airline_seat_recline_normal_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surf2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.hair),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                'SEAT',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: colors.tx3,
                letterSpacing: 1.2,
                poppins: true,
              ),
              const SizedBox(height: 2),
              AppText(
                seat.code,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.amber,
                poppins: true,
                letterSpacing: 0.5,
              ),
            ],
          ),
          Container(
            width: 1,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: colors.hair,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  seat.fullLabel,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.tx1,
                  poppins: true,
                ),
                const SizedBox(height: 2),
                AppText(
                  seat.rowLabel,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.tx3,
                  poppins: true,
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.hair),
            ),
            child: Icon(
              _icon,
              size: 20,
              color: seat == _CarSeatId.drv
                  ? AppColors.amber.withValues(alpha: 0.85)
                  : colors.tx2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom panel
// ─────────────────────────────────────────────────────────────────────────────

class _RoadBottomPanel extends StatelessWidget {
  final _CarSeatId? selected;
  final Animation<Offset> slideAnim;
  final double bottomPad;
  final VoidCallback? onContinue;

  const _RoadBottomPanel({
    required this.selected,
    required this.slideAnim,
    required this.bottomPad,
    this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final has = selected != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F12),
        border: Border(top: BorderSide(color: colors.hair)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (has)
            SlideTransition(
              position: slideAnim,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _CarSeatInfoCard(seat: selected!),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_car_rounded,
                    size: 18,
                    color: colors.tx3.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppText(
                      'Tap a seat to choose your spot',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.tx3,
                      poppins: true,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 16),
            child: _RoadContinueButton(
              enabled: has,
              onTap: onContinue,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadContinueButton extends StatelessWidget {
  const _RoadContinueButton({required this.enabled, this.onTap});

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: enabled ? AppColors.amber : colors.surf3,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled ? AppColors.amber : colors.hair,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.confirmation_number_outlined,
                size: 20,
                color: enabled
                    ? const Color(0xFF0A0B0D)
                    : colors.tx3.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 10),
              AppText(
                enabled ? 'road_seat_pass'.tr : 'road_seat_choose'.tr,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: enabled
                    ? const Color(0xFF0A0B0D)
                    : colors.tx3.withValues(alpha: 0.45),
                poppins: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legend
// ─────────────────────────────────────────────────────────────────────────────

class _RoadLegend extends StatelessWidget {
  const _RoadLegend();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surf2.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.hair.withValues(alpha: 0.8)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 10,
        children: [
          _LegendDot(color: colors.card, borderColor: colors.hair2, label: 'Available'),
          _LegendDot(color: AppColors.amber, borderColor: AppColors.amber, label: 'Selected'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final Color borderColor;
  final String label;

  const _LegendDot({
    required this.color,
    required this.borderColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: borderColor, width: 1.2),
          ),
        ),
        const SizedBox(width: 6),
        AppText.caption(
          label,
          color: Colors.white.withValues(alpha: 0.65),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RoadSeatView — main entry point
// ─────────────────────────────────────────────────────────────────────────────

class RoadSeatView extends StatefulWidget {
  final String fromCity;
  final String fromCountry;
  final String toCity;
  final String toCountry;
  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;
  final double? distanceKm;
  final Duration? duration;
  final List<List<double>> routeCoords;

  const RoadSeatView({
    super.key,
    required this.fromCity,
    required this.fromCountry,
    required this.toCity,
    required this.toCountry,
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
    this.distanceKm,
    this.duration,
    this.routeCoords = const [],
  });

  @override
  State<RoadSeatView> createState() => _RoadSeatViewState();
}

class _RoadSeatViewState extends State<RoadSeatView>
    with TickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;
  late final AnimationController _entranceCtrl;
  late final Animation<double> _entranceAnim;

  _CarSeatId? _selected;

  @override
  void initState() {
    super.initState();

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic),
    );

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _entranceAnim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOutCubic,
    );
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  void _selectSeat(_CarSeatId seat) {
    HapticFeedback.selectionClick();
    setState(() => _selected = seat);
    _slideCtrl.forward(from: 0);
  }

  void _onContinue() {
    final seat = _selected;
    if (seat == null) return;
    Get.to(() => RoadTripPassView(
          fromCity: widget.fromCity,
          fromCountry: widget.fromCountry,
          toCity: widget.toCity,
          toCountry: widget.toCountry,
          seatCode: seat.code,
          distanceKm: widget.distanceKm ?? 0,
          duration: widget.duration ?? Duration.zero,
          fromLat: widget.fromLat,
          fromLng: widget.fromLng,
          toLat: widget.toLat,
          toLng: widget.toLng,
          routeCoords: widget.routeCoords,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF080A0D),
      body: Stack(
        children: [
          // ── Dark background ───────────────────────────────────────────────
          const Positioned.fill(
            child: ColoredBox(color: Color(0xFF080A0D)),
          ),

          // ── Content ───────────────────────────────────────────────────────
          Column(
            children: [
              _RoadSeatHeader(
                fromCity: widget.fromCity,
                fromCountry: widget.fromCountry,
                toCity: widget.toCity,
                toCountry: widget.toCountry,
                distanceKm: widget.distanceKm,
                duration: widget.duration,
                topPad: mq.padding.top,
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.only(
                    top: 24,
                    left: 8,
                    right: 8,
                    bottom: mq.padding.bottom + 240,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Column(
                      children: [
                        // Top-down car diagram
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  const Color(0xFF4A5260).withValues(alpha: 0.4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.55),
                                blurRadius: 28,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: _CarDiagram(
                              selected: _selected,
                              onSeatTap: _selectSeat,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const _RoadLegend(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Fixed bottom panel ────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _RoadBottomPanel(
              selected: _selected,
              slideAnim: _slideAnim,
              bottomPad: mq.padding.bottom,
              onContinue: _onContinue,
            ),
          ),

          // ── Amber entrance reveal ─────────────────────────────────────────
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _entranceAnim,
              builder: (ctx, _) {
                final t = _entranceAnim.value;
                if (t >= 1.0) return const SizedBox.shrink();
                return Opacity(
                  opacity: (1.0 - t).clamp(0.0, 1.0),
                  child: const ColoredBox(
                    color: Color(0xFFF6A93B),
                    child: SizedBox.expand(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
