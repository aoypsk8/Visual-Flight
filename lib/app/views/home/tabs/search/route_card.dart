import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

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
  final bool fromIsMapPin;
  final bool toIsMapPin;
  final bool pickingFromOnMap;
  final bool pickingToOnMap;
  final double? distanceKm;
  final Duration? flightDuration;
  final SearchRouteUxStep step;
  final String? routeLabel;
  final VoidCallback onFromTap;
  final VoidCallback onPickFromOnMap;
  final VoidCallback onUseMyLocation;
  final VoidCallback onPickToOnMap;
  final VoidCallback onToTap;
  final VoidCallback onSwap;
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
    this.fromIsMapPin = false,
    this.toIsMapPin = false,
    this.pickingFromOnMap = false,
    this.pickingToOnMap = false,
    this.distanceKm,
    this.flightDuration,
    this.routeLabel,
    required this.onFromTap,
    required this.onPickFromOnMap,
    required this.onUseMyLocation,
    required this.onPickToOnMap,
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

  bool get _showFromGps =>
      fromIsMapPin || (from != null && !fromIsCurrentLocation);

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xD0131519),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _emphasizeDestination
              ? AppColors.amber.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onCollapse != null || routeLabel != null)
            _RouteCardTopBar(label: routeLabel, onCollapse: onCollapse),
          SearchAirportRow(
            roleKey: 'search_role_from',
            airport: from,
            icon: fromIsMapPin
                ? Icons.push_pin_rounded
                : Icons.my_location_rounded,
            isTop: routeLabel == null && onCollapse == null,
            isLoading: loadingFrom,
            isCurrentLocation: fromIsCurrentLocation,
            isMapPin: fromIsMapPin,
            emphasize: false,
            pinningOnMap: pickingFromOnMap,
            onTap: onFromTap,
            onPinTap: onPickFromOnMap,
            onAltTap: !loadingFrom && _showFromGps ? onUseMyLocation : null,
            altIcon: Icons.near_me_outlined,
          ),
          _ConnectorRow(
            step: step,
            loadingRoadRoute: loadingRoadRoute,
            swapEnabled: to != null && from != null,
            onSwap: onSwap,
          ),
          SearchAirportRow(
            roleKey: 'search_role_to',
            airport: to,
            icon: toIsMapPin
                ? Icons.push_pin_rounded
                : Icons.flight_land_rounded,
            isTop: false,
            emphasize: _emphasizeDestination,
            isMapPin: toIsMapPin,
            pinningOnMap: pickingToOnMap,
            onTap: onToTap,
            onPinTap: onPickToOnMap,
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
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 0),
      child: Row(
        children: [
          if (label != null) ...[
            Icon(
              Icons.check_circle_outline_rounded,
              size: 15,
              color: AppColors.amber.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppText(
                label!,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.75),
                poppins: true,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            const Spacer(),
          if (onCollapse != null) _CollapseChipButton(onTap: onCollapse!),
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
      label: 'search_hide_panel'.tr,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: AppColors.amber.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(
              Icons.keyboard_double_arrow_down_rounded,
              size: 20,
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
        ? 'search_connector_finding_road'.tr
        : switch (step) {
            SearchRouteUxStep.findingOrigin =>
              'search_connector_setting_origin'.tr,
            SearchRouteUxStep.chooseDestination =>
              'search_connector_pick_dest'.tr,
            SearchRouteUxStep.routeReady => 'search_connector_direct'.tr,
          };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: AppText(
              hint,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.32),
              poppins: true,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: enabled
                  ? AppColors.amber.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Icon(
            Icons.swap_vert_rounded,
            size: 18,
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.amber.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppText(
              'search_calculating_drive'.tr,
              fontSize: 12,
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FooterStat(
              value: distance,
              label: 'search_stat_distance'.tr,
            ),
          ),
          Container(
            width: 1,
            height: 28,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          Expanded(
            child: _FooterStat(
              value: duration,
              label: isDrive
                  ? 'search_stat_est_drive'.tr
                  : 'search_stat_est_flight'.tr,
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
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Colors.white.withValues(alpha: 0.32),
          poppins: true,
        ),
        const SizedBox(height: 2),
        AppText(
          value,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.88),
          poppins: true,
        ),
      ],
    );
  }
}
