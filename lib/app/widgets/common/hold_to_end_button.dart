import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/app_colors.dart';
import 'app_text.dart';

/// ระยะวางปุ่ม hold เหนือ HUD ให้สอดคล้องกันทั้ง Flight / Car
class HoldToEndLayout {
  HoldToEndLayout._();

  static const compactCircleSize = 64.0;
  static const gapAboveHud = 12.0;

  /// ค่า `Positioned.bottom` จากขอบล่าง SafeArea
  static double bottomInset({
    required MediaQueryData mq,
    required double hudBodyHeight,
    double hudOuterBottomPadding = 12,
    double gapAboveHud = HoldToEndLayout.gapAboveHud,
  }) {
    return mq.padding.bottom +
        hudOuterBottomPadding +
        hudBodyHeight +
        gapAboveHud;
  }
}

/// กดค้าง 3 วินาทีเพื่อจบ session ก่อนเวลา (progress ยังวิ่งต่อระหว่างกด)
class HoldToEndButton extends StatefulWidget {
  const HoldToEndButton({
    super.key,
    required this.onHoldComplete,
    this.enabled = true,
    this.compact = true,
    this.alignEnd = true,
    this.idleHint = 'Hold 3 s to end session',
    this.semanticsLabel = 'Hold for three seconds to end session',
  });

  final VoidCallback onHoldComplete;
  final bool enabled;
  final bool compact;
  final bool alignEnd;
  final String idleHint;
  final String semanticsLabel;

  @override
  State<HoldToEndButton> createState() => _HoldToEndButtonState();
}

class _HoldToEndButtonState extends State<HoldToEndButton>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(seconds: 3);

  late final AnimationController _holdCtrl;
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    _holdCtrl = AnimationController(vsync: this, duration: _holdDuration)
      ..addStatusListener(_onHoldStatus);
  }

  @override
  void dispose() {
    _holdCtrl.removeStatusListener(_onHoldStatus);
    _holdCtrl.dispose();
    super.dispose();
  }

  void _onHoldStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _holding) {
      _holding = false;
      widget.onHoldComplete();
    }
  }

  void _pointerDown(PointerDownEvent _) {
    if (!widget.enabled || _holding) return;
    _holding = true;
    HapticFeedback.lightImpact();
    _holdCtrl.forward(from: _holdCtrl.value);
  }

  void _pointerUp(PointerUpEvent _) {
    if (!_holding) return;
    _holding = false;
    if (_holdCtrl.status != AnimationStatus.completed) {
      _holdCtrl.reverse();
      HapticFeedback.selectionClick();
    }
  }

  void _pointerCancel(PointerCancelEvent _) {
    if (!_holding) return;
    _holding = false;
    _holdCtrl.reverse();
  }

  double get _circleSize =>
      widget.compact ? HoldToEndLayout.compactCircleSize : 76.0;

  @override
  Widget build(BuildContext context) {
    final size = _circleSize;
    return Padding(
      padding: EdgeInsets.only(bottom: widget.compact ? 0 : 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: widget.alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.center,
        children: [
          Listener(
            onPointerDown: widget.enabled ? _pointerDown : null,
            onPointerUp: widget.enabled ? _pointerUp : null,
            onPointerCancel: widget.enabled ? _pointerCancel : null,
            child: AnimatedBuilder(
              animation: _holdCtrl,
              builder: (context, child) {
                final t = _holdCtrl.value.clamp(0.0, 1.0);
                final secsLeft =
                    ((_holdDuration.inMilliseconds * (1 - t)) / 1000)
                        .ceil()
                        .clamp(0, 3);

                return Semantics(
                  button: true,
                  label: widget.semanticsLabel,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: _holding
                          ? [
                              BoxShadow(
                                color: AppColors.amber
                                    .withValues(alpha: 0.22 * t),
                                blurRadius: 18,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: ClipOval(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: Size(size, size),
                            painter: HoldCircleFillPainter(
                              progress: t,
                              holding: _holding,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _holding
                                    ? Icons.stop_rounded
                                    : Icons.touch_app_outlined,
                                size: widget.compact ? 22 : 26,
                                color: _holding
                                    ? (t > 0.4
                                        ? Colors.white
                                        : AppColors.amber)
                                    : Colors.white.withValues(alpha: 0.5),
                              ),
                              if (_holding) ...[
                                const SizedBox(height: 2),
                                AppText(
                                  '$secsLeft',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: t > 0.4
                                      ? Colors.white
                                      : AppColors.amber,
                                  poppins: true,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: widget.compact ? 6 : 8),
          AppText(
            _holding ? 'Release to cancel' : widget.idleHint,
            fontSize: widget.compact ? 11 : 12,
            fontWeight: FontWeight.w600,
            color: _holding
                ? AppColors.amber.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.5),
            poppins: true,
            textAlign: widget.alignEnd ? TextAlign.right : TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// เติมสีวงกลมแบบ sweep ตามเวลากดค้าง (เริ่มจากด้านบน หมุนตามเข็มนาฬิกา)
class HoldCircleFillPainter extends CustomPainter {
  HoldCircleFillPainter({required this.progress, required this.holding});

  final double progress;
  final bool holding;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFF16181D).withValues(alpha: 0.92),
    );

    if (progress > 0) {
      final fill = Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [
            AppColors.amber.withValues(alpha: 0.5 + 0.25 * progress),
            const Color(0xFFE8A838).withValues(alpha: 0.85),
            AppColors.amber.withValues(alpha: 0.55 + 0.3 * progress),
          ],
          stops: const [0.0, 0.55, 1.0],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(rect);

      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress,
        true,
        fill,
      );
    }

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = holding ? 2 : 1.5
      ..color = holding
          ? AppColors.amber.withValues(alpha: 0.5 + 0.25 * progress)
          : Colors.white.withValues(alpha: 0.14);
    canvas.drawCircle(center, radius - border.strokeWidth / 2, border);
  }

  @override
  bool shouldRepaint(covariant HoldCircleFillPainter old) =>
      old.progress != progress || old.holding != holding;
}
