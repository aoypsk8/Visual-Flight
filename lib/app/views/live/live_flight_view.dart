import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../models/live_flight_session.dart';
import '../../services/flight_audio_service.dart';
import '../../services/live_flight_session_store.dart';
import '../../utils/app_colors.dart';
import '../../utils/live_flight_progress.dart';
import '../../widgets/common/app_text.dart';
import '../../widgets/common/hold_to_end_button.dart';
import 'landing_view.dart';
import 'live_flight_map_layer.dart';

/// In-flight focus session — real-time progress + map view.
class LiveFlightView extends StatefulWidget {
  const LiveFlightView({super.key, required this.session});

  final LiveFlightSession session;

  @override
  State<LiveFlightView> createState() => _LiveFlightViewState();
}

class _LiveFlightViewState extends State<LiveFlightView>
    with TickerProviderStateMixin {
  late LiveFlightSession _session;
  late final AnimationController _endAnimCtrl;
  Ticker? _liveTicker;
  double _progress = 0;
  bool _isEnding = false;
  bool _uiHidden = false;
  final FlightAudioService _flightAudio = FlightAudioService();

  void _toggleUiHidden() {
    HapticFeedback.selectionClick();
    setState(() => _uiHidden = !_uiHidden);
  }

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    LiveFlightSessionStore.save(_session);
    _endAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _tickProgress();
    _liveTicker = createTicker((_) => _tickProgress())..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_flightAudio.startFlight());
    });
  }

  @override
  void dispose() {
    _flightAudio.dispose();
    _liveTicker?.dispose();
    _endAnimCtrl.dispose();
    super.dispose();
  }

  bool _completionScheduled = false;
  bool _navigatedAway = false;

  void _tickProgress() {
    if (!mounted || _isEnding) return;
    final p = _session.progressAt(DateTime.now());
    if (p >= 1.0) {
      _scheduleCompletion();
      return;
    }
    if (p != _progress) {
      setState(() => _progress = p);
    }
  }

  void _scheduleCompletion() {
    if (_completionScheduled || _navigatedAway || !mounted) return;
    _completionScheduled = true;
    _liveTicker?.stop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_onComplete());
    });
  }

  Future<void> _onHoldStopComplete() async {
    if (_isEnding) return;
    setState(() => _isEnding = true);
    _liveTicker?.stop();
    HapticFeedback.heavyImpact();
    await _endAnimCtrl.forward(from: 0);
    if (!mounted) return;
    await _onComplete();
  }

  Future<void> _onComplete() async {
    if (_navigatedAway || !mounted) return;
    _navigatedAway = true;
    _liveTicker?.stop();
    LiveFlightSessionStore.clear();
    if (!_isEnding) HapticFeedback.heavyImpact();
    await _flightAudio.playLanding();
    if (!mounted) return;
    Get.off(() => LandingView(session: _session));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // ความสูงเนื้อหา HUD โดยประมาณ (ไม่รวม safe area) — ใช้จัดตำแหน่งปุ่ม hold
    const flightHudBodyHeight = 168.0;
    final holdBottom = HoldToEndLayout.bottomInset(
      mq: mq,
      hudBodyHeight: flightHudBodyHeight,
      hudOuterBottomPadding: 16,
    );

    final derived = LiveFlightProgress(
      progress: _progress,
      totalMin: _session.totalSeconds / 60.0,
      totalKm: _session.totalKm,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0C0D10),
      body: Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0.35).animate(
              CurvedAnimation(parent: _endAnimCtrl, curve: Curves.easeIn),
            ),
            child: _LiveFlightLayers(
              session: _session,
              progress: _progress,
              uiHidden: _uiHidden,
            ),
          ),
          AnimatedOpacity(
            opacity: _uiHidden ? 0 : 1,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            child: IgnorePointer(
              ignoring: _uiHidden,
              child: const _LegibilityScrim(strong: true),
            ),
          ),
          AnimatedOpacity(
            opacity: _uiHidden ? 0 : 1,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            child: IgnorePointer(
              ignoring: _uiHidden,
              child: SafeArea(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LiveFlightTopBar(session: _session),
                        const Spacer(),
                        _LiveFlightHud(
                          session: _session,
                          derived: derived,
                          progress: _progress,
                        ),
                      ],
                    ),
                    // ปุ่ม hold — มุมขวาเหนือ HUD (ไม่ถูก Column stretch ดึงกลางจอ)
                    Positioned(
                      right: 16,
                      bottom: holdBottom,
                      child: HoldToEndButton(
                        enabled: !_isEnding,
                        onHoldComplete: _onHoldStopComplete,
                        idleHint: 'flight_hold_end'.tr,
                        semanticsLabel:
                            'flight_hold_end_detail'.tr,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                child: _ImmersiveUiToggle(
                  hidden: _uiHidden,
                  onPressed: _toggleUiHidden,
                ),
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: _uiHidden ? 1 : 0,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            child: IgnorePointer(
              ignoring: !_uiHidden,
              child: SafeArea(
                child: Stack(
                  children: [
                    // แถบสถิติเล็กลอยบนแผนที่ — ไม่บังทั้งจอ
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 12,
                      child: Center(
                        child: _CompactFlightStatsPill(derived: derived),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isEnding) _EndingFlightOverlay(animation: _endAnimCtrl),
        ],
      ),
    );
  }
}

class _LiveFlightLayers extends StatelessWidget {
  const _LiveFlightLayers({
    required this.session,
    required this.progress,
    this.uiHidden = false,
  });

  final LiveFlightSession session;
  final double progress;
  final bool uiHidden;

  @override
  Widget build(BuildContext context) {
    if (!session.hasMapCoords) {
      return _SchematicRouteView(
        fromCode: session.fromCode,
        toCode: session.toCode,
        progress: progress,
      );
    }
    return LiveFlightMapLayer(
      fromCode: session.fromCode,
      toCode: session.toCode,
      fromLat: session.fromLat!,
      fromLng: session.fromLng!,
      toLat: session.toLat!,
      toLng: session.toLng!,
      startedAt: session.startedAt,
      totalSeconds: session.totalSeconds,
      progress: progress,
      followCamera: true,
      uiHidden: uiHidden,
    );
  }
}

class _LegibilityScrim extends StatelessWidget {
  const _LegibilityScrim({required this.strong});

  final bool strong;

  @override
  Widget build(BuildContext context) {
    final top = strong ? 0.45 : 0.35;
    final bottom = strong ? 0.55 : 0.42;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0C0D10).withValues(alpha: top),
              Colors.transparent,
              const Color(0xFF0C0D10).withValues(alpha: bottom),
            ],
            stops: const [0.0, 0.42, 1.0],
          ),
        ),
      ),
    );
  }
}

/// Vertical schematic route (design reference) when coords are missing.
class _SchematicRouteView extends StatelessWidget {
  const _SchematicRouteView({
    required this.fromCode,
    required this.toCode,
    required this.progress,
  });

  final String fromCode;
  final String toCode;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0C0D10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final routeH = (constraints.maxHeight - 160).clamp(200.0, 600.0);
          final planeY = progress * routeH;

          return Column(
            children: [
              const SizedBox(height: 56),
              _RouteEndpoint(code: fromCode, isOrigin: true),
              const SizedBox(height: 12),
              SizedBox(
                height: routeH,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Center(
                      child: CustomPaint(
                        size: Size(2, routeH),
                        painter: _SchematicRoutePainter(progress: progress),
                      ),
                    ),
                    Positioned(
                      top: planeY.clamp(0, routeH - 32),
                      left: 0,
                      right: 0,
                      child: Center(child: _PlaneMarkerPulse()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _RouteEndpoint(code: toCode, isOrigin: false),
              const Spacer(),
            ],
          );
        },
      ),
    );
  }
}

class _SchematicRoutePainter extends CustomPainter {
  _SchematicRoutePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final midX = size.width / 2;

    final base = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const dash = 6.0;
    for (double y = 0; y < h; y += dash * 2) {
      canvas.drawLine(Offset(midX, y), Offset(midX, y + dash), base);
    }

    final flownH = h * progress;
    canvas.drawLine(
      Offset(midX, 0),
      Offset(midX, flownH),
      Paint()
        ..color = AppColors.amber
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SchematicRoutePainter old) =>
      old.progress != progress;
}

class _RouteEndpoint extends StatelessWidget {
  const _RouteEndpoint({required this.code, required this.isOrigin});

  final String code;
  final bool isOrigin;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOrigin ? Colors.white : AppColors.amber,
            border: Border.all(
              color: isOrigin ? AppColors.amber : Colors.white,
              width: 2,
            ),
          ),
        ),
        const SizedBox(height: 6),
        AppText(
          code,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.85),
          poppins: true,
        ),
      ],
    );
  }
}

class _PlaneMarkerPulse extends StatefulWidget {
  @override
  State<_PlaneMarkerPulse> createState() => _PlaneMarkerPulseState();
}

class _PlaneMarkerPulseState extends State<_PlaneMarkerPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 36 + t * 12,
              height: 36 + t * 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.amber.withValues(alpha: 0.16 * (1 - t)),
              ),
            ),
            Transform.rotate(
              angle: 3.14159,
              child: Icon(
                Icons.airplanemode_active_rounded,
                size: 26,
                color: AppColors.amber,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LiveFlightTopBar extends StatelessWidget {
  const _LiveFlightTopBar({required this.session});

  final LiveFlightSession session;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 56, 0),
      child: Row(
        children: [
          _LiveBadge(),
          const SizedBox(width: 10),
          _RouteChip(
            from: session.fromCode,
            to: session.toCode,
          ),
        ],
      ),
    );
  }
}

/// ปุ่มซ่อน/แสดง UI ทั้งหมด — โหมด immersive
class _ImmersiveUiToggle extends StatelessWidget {
  const _ImmersiveUiToggle({
    required this.hidden,
    required this.onPressed,
  });

  final bool hidden;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: hidden ? 0.35 : 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hidden
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.14),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 18,
                color: hidden ? AppColors.amber : Colors.white70,
              ),
              const SizedBox(width: 6),
              AppText(
                hidden ? 'flight_show_ui'.tr : 'flight_clean_view'.tr,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: hidden ? AppColors.amber : Colors.white70,
                poppins: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactFlightStatsPill extends StatelessWidget {
  const _CompactFlightStatsPill({required this.derived});

  final LiveFlightProgress derived;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF16181D).withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CompactStat(
                label: 'LEFT',
                value: derived.remainingLabel,
                mono: true,
              ),
              _pillDivider(),
              _CompactStat(
                label: 'KM',
                value: '${derived.distanceLeftKm}',
              ),
              _pillDivider(),
              _CompactStat(
                label: 'TIME',
                value: derived.elapsedLabel,
                mono: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        width: 1,
        height: 22,
        color: Colors.white.withValues(alpha: 0.12),
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  const _CompactStat({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppText(
          label,
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.4),
          letterSpacing: 1,
          poppins: true,
        ),
        const SizedBox(height: 2),
        AppText(
          value,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          poppins: !mono,
        ),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF16181D).withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulsingDot(),
              const SizedBox(width: 8),
              AppText(
                'LIVE FLIGHT',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.6,
                poppins: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.amber.withValues(alpha: 0.5 + _c.value * 0.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.amber.withValues(alpha: 0.35),
                blurRadius: 6,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RouteChip extends StatelessWidget {
  const _RouteChip({required this.from, required this.to});

  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppText(
            from,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            poppins: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.flight_rounded,
              size: 14,
              color: AppColors.amber.withValues(alpha: 0.9),
            ),
          ),
          AppText(
            to,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            poppins: true,
          ),
        ],
      ),
    );
  }
}

class _LiveFlightHud extends StatelessWidget {
  const _LiveFlightHud({
    required this.session,
    required this.derived,
    required this.progress,
  });

  final LiveFlightSession session;
  final LiveFlightProgress derived;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFF16181D).withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _HudMetric(
                        label: 'REMAINING',
                        value: derived.remainingLabel,
                        mono: true,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    Expanded(
                      child: _HudMetric(
                        label: 'DISTANCE',
                        value: derived.distanceLeftLabel,
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
                if (derived.altitudeFlavor != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppText(
                      derived.altitudeFlavor!,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.4),
                      poppins: true,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _ReadOnlyScrubber(
                  session: session,
                  derived: derived,
                  progress: progress,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HudMetric extends StatelessWidget {
  const _HudMetric({
    required this.label,
    required this.value,
    this.mono = false,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool mono;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.38),
          letterSpacing: 1.2,
          poppins: true,
        ),
        const SizedBox(height: 4),
        AppText(
          value,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.5,
          poppins: !mono,
        ),
      ],
    );
  }
}

class _ReadOnlyScrubber extends StatelessWidget {
  const _ReadOnlyScrubber({
    required this.session,
    required this.derived,
    required this.progress,
  });

  final LiveFlightSession session;
  final LiveFlightProgress derived;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final knobX = (progress * w).clamp(18.0, w - 18);
            return SizedBox(
              height: 28,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: knobX,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Positioned(
                    left: knobX - 14,
                    top: 2,
                    child: Container(
                      width: 28,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.amber,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.amber.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.airplanemode_active_rounded,
                        size: 16,
                        color: Color(0xFF0A0B0D),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            AppText(
              '${session.fromCode} · ${derived.elapsedLabel}',
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.4),
              poppins: true,
            ),
            const Spacer(),
            AppText(
              derived.percentLabel,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.amber.withValues(alpha: 0.85),
              poppins: true,
            ),
            const Spacer(),
            AppText(
              '${derived.remainingLabel} / ${derived.totalLabel} · ${session.toCode}',
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.4),
              poppins: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _EndingFlightOverlay extends StatelessWidget {
  const _EndingFlightOverlay({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          return ColoredBox(
            color: const Color(0xFF0C0D10).withValues(alpha: 0.55 * t),
            child: Center(
              child: Opacity(
                opacity: t,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.amber,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppText(
                      'flight_ending'.tr,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      poppins: true,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
