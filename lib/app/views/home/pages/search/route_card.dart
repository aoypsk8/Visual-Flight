import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../models/airport_model.dart';
import '../../../../utils/app_colors.dart';
import '../../../../utils/flight_route_utils.dart';
import '../../../../widgets/common/app_text.dart';
import 'airport_row.dart';
import 'search_route_ux.dart';

class SearchRouteCard extends StatelessWidget {
  final Airport? from;
  final Airport? to;
  final bool loadingFrom;
  final bool loadingRoadRoute;
  final bool isDriveMode;
  final bool fromIsCurrentLocation;
  final double? distanceKm;
  final Duration? flightDuration;
  final SearchRouteUxStep step;
  final String? routeLabel;
  final VoidCallback onFromTap;
  final VoidCallback onToTap;
  final VoidCallback onSwap;
  /// When set, shows a “−” control in the card header to collapse the panel.
  final VoidCallback? onCollapse;

  const SearchRouteCard({
    super.key,
    required this.from,
    required this.to,
    required this.loadingFrom,
    this.loadingRoadRoute = false,
    this.isDriveMode = false,
    required this.step,
    this.fromIsCurrentLocation = false,
    this.distanceKm,
    this.flightDuration,
    this.routeLabel,
    required this.onFromTap,
    required this.onToTap,
    required this.onSwap,
    this.onCollapse,
  });

  bool get _hasRoute =>
      step == SearchRouteUxStep.routeReady &&
      distanceKm != null &&
      flightDuration != null;

  bool get _emphasizeDestination =>
      step == SearchRouteUxStep.chooseDestination && !loadingFrom;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xD0131519),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _emphasizeDestination
              ? AppColors.amber.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onCollapse != null || routeLabel != null)
            _RouteCardTopBar(label: routeLabel, onCollapse: onCollapse),
          SearchAirportRow(
            role: 'FROM',
            airport: from,
            icon: Icons.my_location_rounded,
            isTop: routeLabel == null && onCollapse == null,
            isLoading: loadingFrom,
            isCurrentLocation: fromIsCurrentLocation,
            onTap: onFromTap,
          ),
          _ConnectorRow(
            step: step,
            loadingRoadRoute: loadingRoadRoute,
            swapEnabled: to != null && from != null,
            onSwap: onSwap,
          ),
          SearchAirportRow(
            role: 'TO',
            airport: to,
            icon: Icons.flight_land_rounded,
            isTop: false,
            emphasize: _emphasizeDestination,
            onTap: onToTap,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: loadingRoadRoute && isDriveMode
                ? const _RouteLoadingFooter()
                : _hasRoute
                    ? _RouteSummaryFooter(
                        distanceKm: distanceKm!,
                        flightDuration: flightDuration!,
                        isDrive: isDriveMode,
                      )
                    : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }
}

class _RouteCardTopBar extends StatelessWidget {
  const _RouteCardTopBar({this.label, this.onCollapse});

  final String? label;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
      child: Row(
        children: [
          if (label != null) ...[
            Icon(
              Icons.check_circle_outline_rounded,
              size: 16,
              color: AppColors.amber.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppText(
                label!,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.75),
                poppins: true,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            const Spacer(),
          if (onCollapse != null)
            _CollapseChipButton(onTap: onCollapse!),
        ],
      ),
    );
  }
}

class _CollapseChipButton extends StatelessWidget {
  const _CollapseChipButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Hide route panel',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: AppColors.amber.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(
              Icons.keyboard_double_arrow_down_rounded,
              size: 22,
              color: AppColors.amber.withValues(alpha: 0.88),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectorRow extends StatelessWidget {
  const _ConnectorRow({
    required this.step,
    this.loadingRoadRoute = false,
    required this.swapEnabled,
    required this.onSwap,
  });

  final SearchRouteUxStep step;
  final bool loadingRoadRoute;
  final bool swapEnabled;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final hint = loadingRoadRoute
        ? 'Finding road route…'
        : switch (step) {
            SearchRouteUxStep.findingOrigin => 'Setting up departure',
            SearchRouteUxStep.chooseDestination => 'Next: pick destination',
            SearchRouteUxStep.routeReady => 'Direct · estimate',
          };

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: step == SearchRouteUxStep.routeReady
                        ? AppColors.amber
                        : Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                Container(
                  width: 1,
                  height: 16,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: step == SearchRouteUxStep.chooseDestination
                        ? AppColors.amber.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: AppText(
              hint,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.38),
              poppins: true,
            ),
          ),
          _SwapButton(enabled: swapEnabled, onTap: onSwap),
        ],
      ),
    );
  }
}

class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: enabled
                  ? AppColors.amber.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Icon(
            Icons.swap_vert_rounded,
            size: 20,
            color: enabled
                ? AppColors.amber.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.25),
          ),
        ),
      ),
    );
  }
}

class _RouteLoadingFooter extends StatelessWidget {
  const _RouteLoadingFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
        color: Colors.white.withValues(alpha: 0.02),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.amber.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: AppText(
              'Calculating drive distance & time…',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.72),
              poppins: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteSummaryFooter extends StatelessWidget {
  const _RouteSummaryFooter({
    required this.distanceKm,
    required this.flightDuration,
    this.isDrive = false,
  });

  final double distanceKm;
  final Duration flightDuration;
  final bool isDrive;

  @override
  Widget build(BuildContext context) {
    final distance = FlightRouteUtils.formatDistance(distanceKm);
    final duration = FlightRouteUtils.formatDurationCompact(flightDuration);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
        color: Colors.white.withValues(alpha: 0.02),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FooterStat(value: distance, label: 'Distance'),
          ),
          Container(
            width: 1,
            height: 32,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          Expanded(
            child: _FooterStat(
              value: duration,
              label: isDrive ? 'Est. drive' : 'Est. flight',
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterStat extends StatelessWidget {
  const _FooterStat({
    required this.value,
    required this.label,
    this.alignEnd = false,
  });

  final String value;
  final String label;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Colors.white.withValues(alpha: 0.32),
          poppins: true,
        ),
        const SizedBox(height: 4),
        AppText(
          value,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.88),
          poppins: true,
          letterSpacing: -0.2,
        ),
      ],
    );
  }
}
