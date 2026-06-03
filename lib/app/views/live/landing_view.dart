import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/live_flight_session.dart';
import '../../routes/app_routes.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_resources.dart';
import '../../utils/live_flight_progress.dart';
import '../../widgets/common/app_text.dart';

/// Shown when live flight progress reaches 100%.
class LandingView extends StatelessWidget {
  const LandingView({super.key, required this.session});

  final LiveFlightSession session;

  @override
  Widget build(BuildContext context) {
    final date = session.startedAt;
    final dateStr =
        '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFF0C0D10),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppUiAssets.finishedFlight,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFF0C0D10)),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0C0D10).withValues(alpha: 0.5),
                  const Color(0xFF0C0D10).withValues(alpha: 0.88),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    'Landed',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.amber,
                    letterSpacing: 2,
                    poppins: true,
                  ),
                  const SizedBox(height: 8),
                  AppText(
                    session.toCity,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    poppins: true,
                    height: 1.05,
                  ),
                  const SizedBox(height: 8),
                  AppText(
                    '${session.fromCode} → ${session.toCode} · Seat ${session.seatCode}',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.55),
                    poppins: true,
                  ),
                  const SizedBox(height: 6),
                  AppText(
                    '${session.totalKm.round()} km · '
                    '${LiveFlightProgress.formatMinutes(session.totalSeconds / 60.0)} · $dateStr',
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.4),
                    poppins: true,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Get.offAllNamed(AppRoutes.home),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.amber,
                        foregroundColor: const Color(0xFF0A0B0D),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Back to home',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
