import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../models/live_flight_session.dart';
import '../../services/live_flight_session_store.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_resources.dart';
import '../../utils/live_flight_progress.dart';
import '../../widgets/common/app_text.dart';
import 'landing_view.dart';
import 'live_flight_map_layer.dart';

enum LiveFlightLayer { map, window, tail }

/// In-flight focus session — real-time progress + Map / Window / Tail views.
class LiveFlightView extends StatefulWidget {
  const LiveFlightView({super.key, required this.session});

  final LiveFlightSession session;

  @override
  State<LiveFlightView> createState() => _LiveFlightViewState();
}

class _LiveFlightViewState extends State<LiveFlightView>
    with TickerProviderStateMixin {
  late LiveFlightSession _session;
  late final AnimationController _fadeCtrl;
  late final AnimationController _endAnimCtrl;
  Ticker? _liveTicker;
  LiveFlightLayer _layer = LiveFlightLayer.map;
  double _progress = 0;
  bool _isEnding = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    LiveFlightSessionStore.save(_session);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..value = 1;
    _endAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _tickProgress();
    _liveTicker = createTicker((_) => _tickProgress())..start();
  }

  @override
  void dispose() {
    _liveTicker?.dispose();
    _fadeCtrl.dispose();
    _endAnimCtrl.dispose();
    super.dispose();
  }

  void _tickProgress() {
    if (!mounted || _isEnding) return;
    final p = _session.progressAt(DateTime.now());
    if (p >= 1.0) {
      _onComplete();
      return;
    }
    if (p != _progress) {
      setState(() => _progress = p);
    }
  }

  Future<void> _onHoldStopComplete() async {
    if (_isEnding) return;
    setState(() => _isEnding = true);
    _liveTicker?.stop();
    HapticFeedback.heavyImpact();
    await _endAnimCtrl.forward(from: 0);
    if (!mounted) return;
    _onComplete();
  }

  void _onComplete() {
    _liveTicker?.stop();
    LiveFlightSessionStore.clear();
    if (!_isEnding) HapticFeedback.heavyImpact();
    Get.off(() => LandingView(session: _session));
  }

  Future<void> _switchLayer(LiveFlightLayer next) async {
    if (next == _layer) return;
    HapticFeedback.selectionClick();
    await _fadeCtrl.animateTo(0, duration: const Duration(milliseconds: 280));
    setState(() => _layer = next);
    await _fadeCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
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
              layer: _layer,
              progress: _progress,
              fade: _fadeCtrl,
            ),
          ),
          _LegibilityScrim(strong: _layer != LiveFlightLayer.map),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LiveFlightTopBar(session: _session),
                const Spacer(),
                _LiveFlightHud(
                  session: _session,
                  derived: derived,
                  progress: _progress,
                  layer: _layer,
                  onLayer: _switchLayer,
                  holdEnabled: !_isEnding,
                  onHoldComplete: _onHoldStopComplete,
                ),
              ],
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
    required this.layer,
    required this.progress,
    required this.fade,
  });

  final LiveFlightSession session;
  final LiveFlightLayer layer;
  final double progress;
  final Animation<double> fade;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fade,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _layerView(LiveFlightLayer.map),
          _layerView(LiveFlightLayer.window),
          _layerView(LiveFlightLayer.tail),
        ],
      ),
    );
  }

  Widget _layerView(LiveFlightLayer mode) {
    final visible = layer == mode;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        child: switch (mode) {
          LiveFlightLayer.map => session.hasMapCoords
              ? LiveFlightMapLayer(
                  fromCode: session.fromCode,
                  toCode: session.toCode,
                  fromLat: session.fromLat!,
                  fromLng: session.fromLng!,
                  toLat: session.toLat!,
                  toLng: session.toLng!,
                  startedAt: session.startedAt,
                  totalSeconds: session.totalSeconds,
                  progress: progress,
                  followCamera: visible,
                )
              : _SchematicRouteView(
                  fromCode: session.fromCode,
                  toCode: session.toCode,
                  progress: progress,
                ),
          LiveFlightLayer.window => _WindowLayerView(progress: progress),
          LiveFlightLayer.tail => const _TailLayerView(),
        },
      ),
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

class _WindowLayerView extends StatelessWidget {
  const _WindowLayerView({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final parallax = (0.5 - progress) * 0.07;

    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.scale(
          scale: 1.18,
          child: Transform.translate(
            offset: Offset(0, parallax * MediaQuery.sizeOf(context).height),
            child: Image.asset(
              AppUiAssets.liveWindow,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF1A2030)),
            ),
          ),
        ),
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 72),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 10,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 40,
                  spreadRadius: -8,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 80,
          left: 48,
          child: Container(
            width: 80,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TailLayerView extends StatelessWidget {
  const _TailLayerView();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppUiAssets.liveTail,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF12151C)),
    );
  }
}

class _LiveFlightTopBar extends StatelessWidget {
  const _LiveFlightTopBar({required this.session});

  final LiveFlightSession session;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
    required this.layer,
    required this.onLayer,
    required this.onHoldComplete,
    this.holdEnabled = true,
  });

  final LiveFlightSession session;
  final LiveFlightProgress derived;
  final double progress;
  final LiveFlightLayer layer;
  final ValueChanged<LiveFlightLayer> onLayer;
  final VoidCallback onHoldComplete;
  final bool holdEnabled;

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
                _HoldToEndFlightButton(
                  enabled: holdEnabled,
                  onHoldComplete: onHoldComplete,
                  compact: true,
                ),
                const SizedBox(height: 12),
                _ViewSegmentedControl(
                  selected: layer,
                  onChanged: onLayer,
                ),
                const SizedBox(height: 14),
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
                if (layer == LiveFlightLayer.map &&
                    derived.altitudeFlavor != null) ...[
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

class _ViewSegmentedControl extends StatelessWidget {
  const _ViewSegmentedControl({
    required this.selected,
    required this.onChanged,
  });

  final LiveFlightLayer selected;
  final ValueChanged<LiveFlightLayer> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _seg('Map', LiveFlightLayer.map),
          _seg('Window', LiveFlightLayer.window),
          _seg('Tail', LiveFlightLayer.tail),
        ],
      ),
    );
  }

  Widget _seg(String label, LiveFlightLayer mode) {
    final on = selected == mode;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(mode),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: on ? AppColors.amber.withValues(alpha: 0.18) : null,
              borderRadius: BorderRadius.circular(10),
              border: on
                  ? Border.all(color: AppColors.amber.withValues(alpha: 0.45))
                  : null,
            ),
            alignment: Alignment.center,
            child: AppText(
              label,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: on ? AppColors.amber : Colors.white.withValues(alpha: 0.45),
              poppins: true,
            ),
          ),
        ),
      ),
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

/// Hold 3 seconds to end the focus session early (live progress keeps running while holding).
class _HoldToEndFlightButton extends StatefulWidget {
  const _HoldToEndFlightButton({
    required this.onHoldComplete,
    this.enabled = true,
    this.compact = false,
  });

  final VoidCallback onHoldComplete;
  final bool enabled;
  final bool compact;

  @override
  State<_HoldToEndFlightButton> createState() => _HoldToEndFlightButtonState();
}

class _HoldToEndFlightButtonState extends State<_HoldToEndFlightButton>
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

  double get _circleSize => widget.compact ? 64.0 : 76.0;

  @override
  Widget build(BuildContext context) {
    final size = _circleSize;
    return Padding(
      padding: EdgeInsets.only(bottom: widget.compact ? 0 : 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Listener(
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
                    label: 'Hold for three seconds to end flight',
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
                              painter: _HoldCircleFillPainter(
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
          ),
          SizedBox(height: widget.compact ? 6 : 8),
          AppText(
            _holding ? 'Release to cancel' : 'Hold 3 s to end flight',
            fontSize: widget.compact ? 11 : 12,
            fontWeight: FontWeight.w600,
            color: _holding
                ? AppColors.amber.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.5),
            poppins: true,
          ),
        ],
      ),
    );
  }
}

/// เติมสีวงกลมแบบ sweep ตามเวลากดค้าง (เริ่มจากด้านบน หมุนตามเข็มนาฬิกา)
class _HoldCircleFillPainter extends CustomPainter {
  _HoldCircleFillPainter({required this.progress, required this.holding});

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
  bool shouldRepaint(covariant _HoldCircleFillPainter old) =>
      old.progress != progress || old.holding != holding;
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
                      'Ending flight…',
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
