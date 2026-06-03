import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../../../controllers/search_controller.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/common/app_text.dart';
import '../../../widgets/navigation/app_bottom_nav.dart';
import 'search/route_card.dart';
import 'search/search_route_ux.dart';

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
      bottomGradientFraction: veryCompact ? 0.48 : compact ? 0.52 : 0.55,
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
              Obx(() {
                final followDevice = ctrl.to.value == null;
                return MapWidget(
                  styleUri: 'mapbox://styles/mapbox/satellite-streets-v12',
                  viewport: followDevice
                      ? const FollowPuckViewportState(
                          zoom: 4.5,
                          pitch: 30.0,
                          bearing: FollowPuckViewportStateBearingConstant(0),
                        )
                      : const IdleViewportState(),
                  onMapCreated: ctrl.onMapCreated,
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

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: layout.height * layout.bottomGradientFraction,
                child: const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Color(0xFF080A0D),
                          Color(0xBB080A0D),
                          Color(0x00080A0D),
                        ],
                        stops: [0.0, 0.62, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              SafeArea(
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
                      child: Obx(
                        () => _SearchTabHeader(
                          step: ctrl.routeUxStep,
                          layout: layout,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _SearchTabBottomPanel(
                      layout: layout,
                      child: Obx(
                        () => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SearchRouteCard(
                              from: ctrl.from.value,
                              to: ctrl.to.value,
                              loadingFrom: ctrl.loadingLocation.value,
                              step: ctrl.routeUxStep,
                              routeLabel: ctrl.routeSummaryLabel,
                              fromIsCurrentLocation: ctrl.fromIsCurrentLocation,
                              distanceKm: ctrl.routeDistanceKm,
                              flightDuration: ctrl.routeFlightDuration,
                              onFromTap: () => ctrl.pickAirport(isFrom: true),
                              onToTap: () => ctrl.pickAirport(isFrom: false),
                              onSwap: ctrl.swap,
                            ),
                            SizedBox(height: layout.sectionGap),
                            _PrimaryActionButton(
                              step: ctrl.routeUxStep,
                              layout: layout,
                              onTap: ctrl.onPrimaryAction,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchTabHeader extends StatelessWidget {
  const _SearchTabHeader({required this.step, required this.layout});

  final SearchRouteUxStep step;
  final _SearchTabLayout layout;

  @override
  Widget build(BuildContext context) {
    final title = step == SearchRouteUxStep.routeReady
        ? 'Your route'
        : 'Find your flight';

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

class _SearchTabBottomPanel extends StatelessWidget {
  const _SearchTabBottomPanel({required this.layout, required this.child});

  final _SearchTabLayout layout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = Align(
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
          child: child,
        ),
      ),
    );

    return Flexible(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: content,
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
    required this.onTap,
  });

  final SearchRouteUxStep step;
  final _SearchTabLayout layout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = step.primaryEnabled;
    final filled = step == SearchRouteUxStep.routeReady;

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
              Icon(
                filled
                    ? Icons.airline_seat_recline_normal_rounded
                    : Icons.flight_takeoff_rounded,
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
                  step.primaryLabel,
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
