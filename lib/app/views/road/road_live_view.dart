import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../models/road_trip_session.dart';
import '../../repositories/road_route_repository.dart';
import '../../utils/app_colors.dart';
import '../../utils/flight_route_utils.dart';
import '../../widgets/common/app_text.dart';
import 'road_arrival_view.dart';
import 'road_live_map_layer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Live driving view
// ─────────────────────────────────────────────────────────────────────────────

class RoadLiveView extends StatefulWidget {
  const RoadLiveView({super.key, required this.session});

  final RoadTripSession session;

  @override
  State<RoadLiveView> createState() => _RoadLiveViewState();
}

class _RoadLiveViewState extends State<RoadLiveView>
    with TickerProviderStateMixin {
  late RoadTripSession _session;
  late final AnimationController _endAnimCtrl;
  Ticker? _liveTicker;
  double _progress = 0;
  bool _isEnding = false;
  bool _uiHidden = false;
  bool _completionScheduled = false;
  bool _navigatedAway = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
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
    _endAnimCtrl.dispose();
    super.dispose();
  }

  void _tickProgress() {
    if (!mounted || _isEnding) return;
    final p = _session.progressAt(DateTime.now());
    if (p >= 1.0) {
      _scheduleCompletion();
      return;
    }
    if (p != _progress) setState(() => _progress = p);
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
    if (!_isEnding) HapticFeedback.heavyImpact();
    if (!mounted) return;
    Get.off(() => RoadArrivalView(session: _session));
  }

  void _toggleUiHidden() {
    HapticFeedback.selectionClick();
    setState(() => _uiHidden = !_uiHidden);
  }

  @override
  Widget build(BuildContext context) {
    final derived = _RoadDerived(
      progress: _progress,
      session: _session,
    );
    final mq = MediaQuery.of(context);
    const hudBodyHeight = 188.0;
    final mapControlsBottom = hudBodyHeight + mq.padding.bottom + 24;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0D10),
      body: Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0.35).animate(
              CurvedAnimation(parent: _endAnimCtrl, curve: Curves.easeIn),
            ),
            child: RoadLiveMapLayer(
              session: _session,
              progress: _progress,
              uiHidden: _uiHidden,
              controlsBottomInset: mapControlsBottom,
            ),
          ),
          AnimatedOpacity(
            opacity: _uiHidden ? 0 : 1,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            child: IgnorePointer(
              ignoring: _uiHidden,
              child: const _RoadLegibilityScrim(),
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
                        _RoadLiveTopBar(session: _session),
                        const Spacer(),
                        _RoadHud(
                          derived: derived,
                          progress: _progress,
                          holdEnabled: !_isEnding,
                          onHoldComplete: _onHoldStopComplete,
                        ),
                      ],
                    ),
                    Positioned(
                      right: 72,
                      bottom: mapControlsBottom - 52,
                      child: _HoldToEndButton(
                        enabled: !_isEnding,
                        onHoldComplete: _onHoldStopComplete,
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
                child: _RoadImmersiveToggle(
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
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _CompactStatsPill(derived: derived),
                  ),
                ),
              ),
            ),
          ),
          if (_isEnding) _EndingOverlay(animation: _endAnimCtrl),
        ],
      ),
    );
  }
}

class _RoadDerived {
  _RoadDerived({required this.progress, required this.session});

  final double progress;
  final RoadTripSession session;

  double get remainKm => session.totalKm * (1 - progress);
  double get elapsedSec => session.totalSeconds * progress;
  double get remainSec => session.totalSeconds * (1 - progress);

  String get remainKmStr =>
      FlightRouteUtils.formatDistance(remainKm.clamp(0, double.infinity));
  String get remainTimeStr => FlightRouteUtils.formatDurationCompact(
        Duration(seconds: remainSec.round()),
      );
  String get elapsedTimeStr => FlightRouteUtils.formatDurationCompact(
        Duration(seconds: elapsedSec.round()),
      );

  double get speedKmh {
    const base = RoadRouteRepository.focusDriveSpeedKmh;
    final noise = 12.0 * math.sin(elapsedSec * 0.03 + 1.2);
    return (base + noise).clamp(base - 15, base + 15);
  }

  String get speedStr => '${speedKmh.round()} km/h';
}

class _RoadLegibilityScrim extends StatelessWidget {
  const _RoadLegibilityScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0C0D10).withValues(alpha: 0.45),
              Colors.transparent,
              const Color(0xFF0C0D10).withValues(alpha: 0.55),
            ],
            stops: const [0.0, 0.42, 1.0],
          ),
        ),
      ),
    );
  }
}

class _RoadLiveTopBar extends StatelessWidget {
  const _RoadLiveTopBar({required this.session});

  final RoadTripSession session;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 56, 0),
      child: Row(
        children: [
          const _RoadLiveBadge(),
          const SizedBox(width: 10),
          Expanded(
            child: _RoadRouteChip(
              from: session.fromCity,
              to: session.toCity,
              meta:
                  'SEAT ${session.seatCode} · ${FlightRouteUtils.formatDistance(session.totalKm)}',
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadLiveBadge extends StatelessWidget {
  const _RoadLiveBadge();

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
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulsingDot(),
              SizedBox(width: 8),
              AppText(
                'LIVE DRIVE',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.4,
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
  const _PulsingDot();

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

class _RoadRouteChip extends StatelessWidget {
  const _RoadRouteChip({
    required this.from,
    required this.to,
    required this.meta,
  });

  final String from;
  final String to;
  final String meta;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText(
                '$from → $to',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                poppins: true,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              AppText(
                meta,
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.45),
                poppins: true,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoadImmersiveToggle extends StatelessWidget {
  const _RoadImmersiveToggle({
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
                hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
                color: hidden ? AppColors.amber : Colors.white70,
              ),
              const SizedBox(width: 6),
              AppText(
                hidden ? 'Show UI' : 'Clean view',
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

class _RoadHud extends StatelessWidget {
  const _RoadHud({
    required this.derived,
    required this.progress,
    required this.holdEnabled,
    required this.onHoldComplete,
  });

  final _RoadDerived derived;
  final double progress;
  final bool holdEnabled;
  final VoidCallback onHoldComplete;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final pct = (progress * 100).round();
    final maxW = mq.size.width > 600 ? 520.0 : double.infinity;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, mq.padding.bottom + 12),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.52),
                  borderRadius: BorderRadius.circular(24),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.09)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _StatCell(
                          icon: Icons.route_rounded,
                          label: 'REMAINING',
                          value: derived.remainKmStr,
                        ),
                        _VertDivider(),
                        _StatCell(
                          icon: Icons.timer_outlined,
                          label: 'ETA',
                          value: derived.remainTimeStr,
                        ),
                        _VertDivider(),
                        _StatCell(
                          icon: Icons.speed_rounded,
                          label: 'SPEED',
                          value: derived.speedStr,
                          valueColor: AppColors.amber,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppText(
                          derived.session.fromCity,
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.40),
                          poppins: true,
                        ),
                        AppText(
                          '$pct%',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.amber,
                          poppins: true,
                        ),
                        AppText(
                          derived.session.toCity,
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.40),
                          poppins: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.10),
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.amber),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: AppText(
                        'DRIVING  ${derived.elapsedTimeStr}',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.28),
                        poppins: true,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.amber, size: 18),
          const SizedBox(height: 5),
          AppText(
            label,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.35),
            poppins: true,
            letterSpacing: 1.1,
          ),
          const SizedBox(height: 3),
          AppText(
            value,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: valueColor ?? Colors.white,
            poppins: true,
            letterSpacing: -0.3,
          ),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

class _HoldToEndButton extends StatefulWidget {
  const _HoldToEndButton({
    required this.enabled,
    required this.onHoldComplete,
  });

  final bool enabled;
  final VoidCallback onHoldComplete;

  @override
  State<_HoldToEndButton> createState() => _HoldToEndButtonState();
}

class _HoldToEndButtonState extends State<_HoldToEndButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _holdCtrl;
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    _holdCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _holdCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && _holding) {
        widget.onHoldComplete();
      }
    });
  }

  @override
  void dispose() {
    _holdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) {
        if (!widget.enabled) return;
        _holding = true;
        HapticFeedback.lightImpact();
        _holdCtrl.forward(from: 0);
      },
      onLongPressEnd: (_) {
        _holding = false;
        _holdCtrl.animateTo(0, duration: const Duration(milliseconds: 300));
      },
      onLongPressCancel: () {
        _holding = false;
        _holdCtrl.animateTo(0, duration: const Duration(milliseconds: 300));
      },
      child: AnimatedBuilder(
        animation: _holdCtrl,
        builder: (context, _) {
          final t = _holdCtrl.value;
          return ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Color.lerp(
                    Colors.black.withValues(alpha: 0.50),
                    AppColors.amber.withValues(alpha: 0.85),
                    t,
                  ),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: Color.lerp(
                      Colors.white.withValues(alpha: 0.12),
                      AppColors.amber,
                      t,
                    )!,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.flag_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.70 + 0.30 * t),
                    ),
                    const SizedBox(width: 6),
                    AppText(
                      t > 0.05 ? 'Release to end…' : 'Hold to end',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.70 + 0.30 * t),
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

class _CompactStatsPill extends StatelessWidget {
  const _CompactStatsPill({required this.derived});

  final _RoadDerived derived;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(50),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText(
                derived.remainKmStr,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                poppins: true,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  width: 1,
                  height: 12,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              AppText(
                derived.speedStr,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.amber,
                poppins: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EndingOverlay extends StatelessWidget {
  const _EndingOverlay({required this.animation});

  final AnimationController animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = Curves.easeIn.transform(animation.value);
        return Opacity(
          opacity: t * 0.82,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  AppColors.amber.withValues(alpha: 0.12),
                  Colors.black.withValues(alpha: 0.88),
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}
