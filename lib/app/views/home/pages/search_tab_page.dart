import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../../../controllers/search_controller.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/common/app_text.dart';
import 'search/route_card.dart';

class SearchTabPage extends StatelessWidget {
  const SearchTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = FlightSearchController.instance;
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF080A0D),
      body: Stack(
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
            height: mq.size.height * 0.30,
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
            height: mq.size.height * 0.55,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.amber,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          AppText(
                            'FOCUSFLIGHT',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.amber,
                            letterSpacing: 3.2,
                            poppins: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      AppText(
                        'Find Your\nFlight',
                        fontSize: 46,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        poppins: true,
                        height: 1.04,
                        letterSpacing: -1.5,
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    mq.padding.bottom + 100,
                  ),
                  child: Obx(
                    () {
                      final canContinue = ctrl.canContinueToSeats;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SearchRouteCard(
                            from: ctrl.from.value,
                            to: ctrl.to.value,
                            loadingFrom: ctrl.loadingLocation.value,
                            fromIsCurrentLocation: ctrl.fromIsCurrentLocation,
                            distanceKm: ctrl.routeDistanceKm,
                            flightDuration: ctrl.routeFlightDuration,
                            onFromTap: () => ctrl.pickAirport(isFrom: true),
                            onToTap: () => ctrl.pickAirport(isFrom: false),
                            onSwap: ctrl.swap,
                          ),
                          const SizedBox(height: 14),
                          _SelectSeatButton(
                            enabled: canContinue,
                            onTap: ctrl.openSeatSelection,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectSeatButton extends StatelessWidget {
  const _SelectSeatButton({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 17),
            decoration: BoxDecoration(
              color: enabled ? AppColors.amber : AppColors.amber.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.airline_seat_recline_normal_rounded,
                  size: 20,
                  color: enabled
                      ? const Color(0xFF0A0B0D)
                      : const Color(0xFF0A0B0D).withValues(alpha: 0.5),
                ),
                const SizedBox(width: 10),
                AppText(
                  enabled ? 'Select seat' : 'Choose a destination',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: enabled
                      ? const Color(0xFF0A0B0D)
                      : const Color(0xFF0A0B0D).withValues(alpha: 0.5),
                  poppins: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
