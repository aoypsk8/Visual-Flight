import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size, Visibility;
import '../../../../config/api_urls.dart';
import '../../../../controllers/search_controller.dart';
import '../../../../utils/app_colors.dart';
import '../../../../widgets/common/app_text.dart';
import '../../../../widgets/map/deferred_map_host.dart';
import '../../../../widgets/map/live_map_chrome.dart';
import '../../../../widgets/navigation/app_bottom_nav.dart';
import 'route_card.dart';
import 'search_route_ux.dart';

/// Breakpoints and scaled spacing for Search tab on phones and tablets.
class _SearchTabLayout {
  _SearchTabLayout._({
    required this.width,
    required this.height,
    required this.textScale,
    required this.horizontalInset,
    required this.headerTopInset,
    required this.titleFontSize,
    required this.hintFontSize,
    required this.brandFontSize,
    required this.bottomClearance,
    required this.topGradientFraction,
    required this.bottomGradientFraction,
    required this.maxContentWidth,
    required this.sectionGap,
    required this.buttonVerticalPadding,
    required this.buttonRadius,
  });

  final double width;
  final double height;
  final double textScale;
  final double horizontalInset;
  final double headerTopInset;
  final double titleFontSize;
  final double hintFontSize;
  final double brandFontSize;
  final double bottomClearance;
  final double topGradientFraction;
  final double bottomGradientFraction;
  final double? maxContentWidth;
  final double sectionGap;
  final double buttonVerticalPadding;
  final double buttonRadius;

  bool get compactBrandBar => height < 700;

  factory _SearchTabLayout.of(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final scale = mq.textScaler.scale(1).clamp(0.85, 1.2);
    final compact = h < 700 || w < 360;
    final veryCompact = h < 640;

    return _SearchTabLayout._(
      width: w,
      height: h,
      textScale: scale,
      horizontalInset: w < 360 ? 16 : w > 600 ? 32 : 20,
      headerTopInset: veryCompact ? 8 : compact ? 16 : 28,
      titleFontSize: (w * 0.105).clamp(30.0, 46.0) / scale,
      hintFontSize: compact ? 13 : 14,
      brandFontSize: compact ? 10 : 11,
      bottomClearance: AppBottomNav.overlayClearance(context),
      topGradientFraction: veryCompact ? 0.24 : compact ? 0.27 : 0.30,
      bottomGradientFraction: veryCompact ? 0.28 : compact ? 0.32 : 0.36,
      maxContentWidth: w > 520 ? 480 : null,
      sectionGap: compact ? 10 : 12,
      buttonVerticalPadding: compact ? 14 : 16,
      buttonRadius: compact ? 14 : 16,
    );
  }
}

class SearchTabPage extends StatelessWidget {
  const SearchTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = FlightSearchController.instance;
    final layout = _SearchTabLayout.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF080A0D),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              DeferredMapHost(
                immediate: true,
                placeholderColor: const Color(0xFF080A0D),
                onMountChanged: (mounted) {
                  if (!mounted) ctrl.onSearchMapUnmounted();
                },
                builder: (context) => MapWidget(
                  key: const ValueKey('search-map'),
                  styleUri: MapboxResourceUris.satelliteStreetsV12,
                  viewport: const FollowPuckViewportState(
                    zoom: 4.5,
                    pitch: 30.0,
                    bearing: FollowPuckViewportStateBearingConstant(0),
                  ),
                  onMapCreated: ctrl.onMapCreated,
                  onStyleLoadedListener: ctrl.onSearchMapStyleLoaded,
                  onTapListener: ctrl.onSearchMapTap,
                ),
              ),

              Obx(() {
                final target = ctrl.mapPinPickTarget.value;
                if (target == null) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  top: MediaQuery.paddingOf(context).top + 12,
                  left: layout.horizontalInset,
                  right: layout.horizontalInset,
                  child: _MapPinHintBar(
                    target: target,
                    onCancel: ctrl.cancelMapPinPicker,
                  ),
                );
              }),

              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: layout.height * layout.topGradientFraction,
                child: const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xD9080A0D), Color(0x00080A0D)],
                      ),
                    ),
                  ),
                ),
              ),

              Obx(() {
                // โหมดปักหมุด — gradient ต่ำลง ไม่บังแผนที่
                final pinning = ctrl.pickingOnMap;
                final fraction = pinning
                    ? 0.14
                    : layout.bottomGradientFraction;
                return Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: layout.height * fraction,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Color(0xFF080A0D).withValues(
                              alpha: pinning ? 0.75 : 0.92,
                            ),
                            Color(0x88080A0D),
                            Color(0x00080A0D),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // โหลดเส้นทางถนน (Car) — overlay บนแผนที่ ไม่บัง route card
              Obx(() {
                final show = ctrl.travelMode.value == TravelMode.drive &&
                    ctrl.loadingRoadRoute.value &&
                    ctrl.to.value != null;
                if (!show) return const SizedBox.shrink();
                return const Positioned.fill(
                  child: IgnorePointer(
                    child: LiveMapLoadingOverlay(
                      message: 'Finding road route…',
                    ),
                  ),
                );
              }),

              Obx(() {
                final pinning = ctrl.pickingOnMap;
                return IgnorePointer(
                  ignoring: pinning,
                  child: Visibility(
                    visible: !pinning,
                    maintainState: true,
                    maintainAnimation: true,
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              layout.horizontalInset,
                              layout.headerTopInset,
                              layout.horizontalInset,
                              0,
                            ),
                            child: _SearchTabHeader(
                              step: ctrl.routeUxStep,
                              travelMode: ctrl.travelMode.value,
                              onToggleMode: ctrl.toggleTravelMode,
                              layout: layout,
                            ),
                          ),
                          const Spacer(),
                          _CollapsibleRoutePanel(
                            layout: layout,
                            buildRouteCard: () => SearchRouteCard(
                              from: ctrl.from.value,
                              to: ctrl.to.value,
                              loadingFrom: ctrl.loadingLocation.value,
                              loadingRoadRoute: ctrl.loadingRoadRoute.value,
                              isDriveMode: ctrl.travelMode.value ==
                                  TravelMode.drive,
                              step: ctrl.routeUxStep,
                              routeLabel: ctrl.routeSummaryLabel,
                              fromIsCurrentLocation:
                                  ctrl.fromIsCurrentLocation,
                              fromIsMapPin: ctrl.fromIsMapPin,
                              toIsMapPin: ctrl.toIsMapPin,
                              pickingFromOnMap: ctrl.mapPinPickTarget.value ==
                                  MapPinPickTarget.from,
                              pickingToOnMap: ctrl.mapPinPickTarget.value ==
                                  MapPinPickTarget.to,
                              distanceKm: ctrl.displayDistanceKm,
                              flightDuration: ctrl.displayDuration,
                              onFromTap: () => ctrl.pickAirport(isFrom: true),
                              onPickFromOnMap: () =>
                                  ctrl.startMapPinPicker(isFrom: true),
                              onPickToOnMap: () =>
                                  ctrl.startMapPinPicker(isFrom: false),
                              onUseMyLocation:
                                  ctrl.useCurrentLocationForOrigin,
                              onToTap: () => ctrl.pickAirport(isFrom: false),
                              onSwap: ctrl.swap,
                            ),
                            actionButton: _PrimaryActionButton(
                              step: ctrl.routeUxStep,
                              layout: layout,
                              travelMode: ctrl.travelMode.value,
                              loadingRoadRoute: ctrl.loadingRoadRoute.value,
                              enabled: ctrl.primaryActionEnabled,
                              onTap: ctrl.onPrimaryAction,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

/// Shown while user is placing a route endpoint pin on the map.
class _MapPinHintBar extends StatelessWidget {
  const _MapPinHintBar({required this.target, required this.onCancel});

  final MapPinPickTarget target;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE816181D),
      borderRadius: BorderRadius.circular(14),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.touch_app_rounded,
              size: 20,
              color: AppColors.amber.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppText(
                target == MapPinPickTarget.from
                    ? 'Tap the map to set your start point'
                    : 'Tap the map to set your destination',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
                poppins: true,
              ),
            ),
            TextButton(
              onPressed: onCancel,
              child: AppText(
                'Cancel',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.amber,
                poppins: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchTabHeader extends StatelessWidget {
  const _SearchTabHeader({
    required this.step,
    required this.travelMode,
    required this.onToggleMode,
    required this.layout,
  });

  final SearchRouteUxStep step;
  final TravelMode travelMode;
  final VoidCallback onToggleMode;
  final _SearchTabLayout layout;

  @override
  Widget build(BuildContext context) {
    final isDrive = travelMode == TravelMode.drive;
    final title = step == SearchRouteUxStep.routeReady
        ? (isDrive ? 'Your drive' : 'Your route')
        : (isDrive ? 'Plan a drive' : 'Find your flight');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: layout.compactBrandBar ? 14 : 16,
              decoration: BoxDecoration(
                color: AppColors.amber,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            AppText(
              'FOCUSFLIGHT',
              fontSize: layout.brandFontSize,
              fontWeight: FontWeight.w700,
              color: AppColors.amber,
              letterSpacing: layout.width < 360 ? 2.4 : 3.2,
              poppins: true,
            ),
            const Spacer(),
          ],
        ),
        SizedBox(height: layout.width < 360 ? 8 : 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: AppText(
            title,
            fontSize: layout.titleFontSize,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            poppins: true,
            height: 1.04,
            letterSpacing: -1.5,
          ),
        ),
        SizedBox(height: layout.width < 360 ? 8 : 12),
        _StepHint(step: step, fontSize: layout.hintFontSize),
      ],
    );
  }
}


/// Route card expands from / collapses into the airplane FAB (bottom-right).
class _CollapsibleRoutePanel extends StatefulWidget {
  const _CollapsibleRoutePanel({
    required this.layout,
    required this.buildRouteCard,
    required this.actionButton,
  });

  final _SearchTabLayout layout;
  final Widget Function() buildRouteCard;
  final Widget actionButton;

  @override
  State<_CollapsibleRoutePanel> createState() => _CollapsibleRoutePanelState();
}

class _CollapsibleRoutePanelState extends State<_CollapsibleRoutePanel>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 400);

  late final AnimationController _controller;
  late final Animation<double> _reveal;
  late final Animation<double> _cardScale;

  bool get _isFullyOpen => _controller.status == AnimationStatus.completed;
  bool get _isFullyClosed => _controller.status == AnimationStatus.dismissed;

  bool _wasExpandedBeforePin = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _reveal = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _cardScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _controller.value = 1;
    _controller.addStatusListener((_) {
      if (mounted) setState(() {});
    });
    ever(
      FlightSearchController.instance.mapPinPickTarget,
      (t) => _onMapPinModeChanged(t != null),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onMapPinModeChanged(bool pinning) {
    if (!mounted) return;
    if (pinning) {
      _wasExpandedBeforePin = _controller.value > 0.5;
    } else if (_wasExpandedBeforePin) {
      if (_isFullyClosed) _controller.forward();
    } else if (!_isFullyClosed && _controller.value > 0.05) {
      _controller.reverse();
    }
    setState(() {});
  }

  void _hide() {
    if (_isFullyClosed || _controller.status == AnimationStatus.reverse) {
      return;
    }
    HapticFeedback.selectionClick();
    _controller.reverse();
  }

  void _show() {
    if (_isFullyOpen || _controller.status == AnimationStatus.forward) {
      return;
    }
    HapticFeedback.selectionClick();
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    // แผงรับ tap เฉพาะตอนเปิดเกือบเต็ม — กัน layer โปร่งใสบังหลัง collapse
    final panelPointerEnabled = _controller.value > 0.92;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: layout.maxContentWidth ?? double.infinity,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            layout.horizontalInset,
            0,
            layout.horizontalInset,
            layout.bottomClearance,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ต้องมี non-positioned child เสมอ — กัน Stack assert ตอนแผงปิด
                IgnorePointer(
                  ignoring: !panelPointerEnabled,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_controller.value > 0.001) ...[
                        ClipRect(
                          child: Align(
                            alignment: Alignment.bottomRight,
                            heightFactor: 1,
                            child: ScaleTransition(
                              scale: _cardScale,
                              alignment: Alignment.bottomRight,
                              child: FadeTransition(
                                opacity: _reveal,
                                child: widget.buildRouteCard(),
                              ),
                            ),
                          ),
                        ),
                        ClipRect(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            heightFactor: 1,
                            child: SizeTransition(
                              sizeFactor: _reveal,
                              axisAlignment: 1,
                              child: FadeTransition(
                                opacity: _reveal,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    top: layout.sectionGap,
                                    right:
                                        _RoutePanelAirplaneToggle.size + 8,
                                  ),
                                  child: widget.actionButton,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: _RoutePanelAirplaneToggle.size + 4),
                    ],
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final expanded = _controller.value > 0.5;
                      return _RoutePanelAirplaneToggle(
                        collapsed: !expanded,
                        onTap: expanded ? _hide : _show,
                      );
                    },
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

/// มุมล่างขวา — ไอคอนยุบเมื่อแผงเปิด / เครื่องบินเมื่อแผงปิด
class _RoutePanelAirplaneToggle extends StatelessWidget {
  const _RoutePanelAirplaneToggle({
    required this.collapsed,
    required this.onTap,
  });

  final bool collapsed;
  final VoidCallback onTap;

  static const double size = 52;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: collapsed ? 'Show route panel' : 'Hide route panel',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          splashColor: Colors.transparent,
          highlightColor: Colors.white.withValues(alpha: 0.06),
          customBorder: const CircleBorder(),
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xE0131519),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                collapsed
                    ? Icons.flight_rounded
                    : Icons.keyboard_double_arrow_down_rounded,
                key: ValueKey(collapsed),
                size: collapsed ? 24 : 22,
                color: AppColors.amber.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepHint extends StatelessWidget {
  const _StepHint({required this.step, this.fontSize = 14});

  final SearchRouteUxStep step;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Row(
        key: ValueKey(step),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step == SearchRouteUxStep.findingOrigin)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.amber.withValues(alpha: 0.8),
                ),
              ),
            ),
          Expanded(
            child: AppText(
              step.hint,
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.55),
              poppins: true,
              height: 1.35,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.step,
    required this.layout,
    required this.travelMode,
    required this.loadingRoadRoute,
    required this.enabled,
    required this.onTap,
  });

  final SearchRouteUxStep step;
  final _SearchTabLayout layout;
  final TravelMode travelMode;
  final bool loadingRoadRoute;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDrive = travelMode == TravelMode.drive;
    final filled = step == SearchRouteUxStep.routeReady;
    // แสดง spinner ตอนดึง Directions (Car + มีปลายทางแล้ว)
    final showLoading =
        isDrive && loadingRoadRoute && step == SearchRouteUxStep.routeReady;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(layout.buttonRadius),
        child: Ink(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: layout.buttonVerticalPadding),
          decoration: BoxDecoration(
            color: filled
                ? AppColors.amber
                : enabled
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(layout.buttonRadius),
            border: Border.all(
              color: filled
                  ? AppColors.amber
                  : enabled
                      ? AppColors.amber.withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showLoading)
                SizedBox(
                  width: layout.width < 360 ? 18 : 20,
                  height: layout.width < 360 ? 18 : 20,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0A0B0D),
                  ),
                )
              else
                Icon(
                  filled
                      ? (isDrive
                          ? Icons.directions_car_rounded
                          : Icons.airline_seat_recline_normal_rounded)
                      : (isDrive
                          ? Icons.directions_car_outlined
                          : Icons.flight_takeoff_rounded),
                  size: layout.width < 360 ? 18 : 20,
                  color: filled
                      ? const Color(0xFF0A0B0D)
                      : enabled
                          ? AppColors.amber
                          : Colors.white.withValues(alpha: 0.3),
                ),
              const SizedBox(width: 10),
              Flexible(
                child: AppText(
                  showLoading
                      ? 'Loading route…'
                      : (filled && isDrive
                          ? 'Select seat'
                          : step.primaryLabel),
                  fontSize: layout.width < 360 ? 15 : 16,
                  fontWeight: FontWeight.w700,
                  color: filled
                      ? const Color(0xFF0A0B0D)
                      : enabled
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.35),
                  poppins: true,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
