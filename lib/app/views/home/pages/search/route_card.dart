import 'package:flutter/material.dart';
import '../../../../models/airport_model.dart';
import '../../../../utils/app_colors.dart';
import '../../../../utils/flight_route_utils.dart';
import '../../../../widgets/common/app_text.dart';
import 'airport_row.dart';

class SearchRouteCard extends StatelessWidget {
  final Airport? from;
  final Airport? to;
  final bool loadingFrom;
  final bool fromIsCurrentLocation;
  final double? distanceKm;
  final Duration? flightDuration;
  final VoidCallback onFromTap;
  final VoidCallback onToTap;
  final VoidCallback onSwap;

  const SearchRouteCard({
    super.key,
    required this.from,
    required this.to,
    required this.loadingFrom,
    this.fromIsCurrentLocation = false,
    this.distanceKm,
    this.flightDuration,
    required this.onFromTap,
    required this.onToTap,
    required this.onSwap,
  });

  bool get _hasRoute =>
      distanceKm != null && flightDuration != null && to != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xD0131519),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
          SearchAirportRow(
            role: 'FROM',
            airport: from,
            icon: Icons.my_location_rounded,
            isTop: true,
            isLoading: loadingFrom,
            isCurrentLocation: fromIsCurrentLocation,
            onTap: onFromTap,
          ),

          _ConnectorRow(
            swapEnabled: to != null,
            onSwap: onSwap,
          ),

          SearchAirportRow(
            role: 'TO',
            airport: to,
            icon: Icons.flight_land_rounded,
            isTop: false,
            onTap: onToTap,
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _hasRoute
                ? _RouteSummaryFooter(
                    distanceKm: distanceKm!,
                    flightDuration: flightDuration!,
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }
}

/// Connector line + swap button — aligned with the 44px airport row icon.
class _ConnectorRow extends StatelessWidget {
  const _ConnectorRow({
    required this.swapEnabled,
    required this.onSwap,
  });

  final bool swapEnabled;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Center(
              child: Container(
                width: 1,
                height: 20,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          const SizedBox(width: 12),
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

/// Route summary footer — distance and flight time.
class _RouteSummaryFooter extends StatelessWidget {
  const _RouteSummaryFooter({
    required this.distanceKm,
    required this.flightDuration,
  });

  final double distanceKm;
  final Duration flightDuration;

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
            child: _FooterStat(
              value: distance,
              unit: 'distance',
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          Expanded(
            child: _FooterStat(
              value: duration,
              unit: 'flight time',
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
    required this.unit,
    this.alignEnd = false,
  });

  final String value;
  final String unit;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        AppText(
          unit,
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
