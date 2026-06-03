import 'package:flutter/material.dart';
import '../../../../models/airport_model.dart';
import '../../../../utils/app_colors.dart';
import '../../../../widgets/common/app_text.dart';

class SearchAirportRow extends StatelessWidget {
  final String    role;
  final Airport?  airport;
  final IconData  icon;
  final bool      isTop;
  final VoidCallback onTap;
  final bool      isLoading;
  final bool      isCurrentLocation;

  const SearchAirportRow({
    super.key,
    required this.role,
    required this.airport,
    required this.icon,
    required this.isTop,
    required this.onTap,
    this.isLoading = false,
    this.isCurrentLocation = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = airport == null && !isLoading;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(18, isTop ? 20 : 14, 18, isTop ? 14 : 20),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.07),
                    Colors.white.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08), width: 1),
              ),
              child: Icon(icon, size: 19,
                  color: isEmpty
                      ? Colors.white.withValues(alpha: 0.20)
                      : Colors.white.withValues(alpha: 0.50)),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    role,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.35),
                    letterSpacing: 1.5,
                    poppins: true,
                  ),
                  const SizedBox(height: 3),

                  if (isLoading) ...[
                    Row(children: [
                      SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: AppColors.amber.withValues(alpha: 0.70),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppText(
                        'Detecting location…',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.45),
                        poppins: true,
                      ),
                    ]),
                    const SizedBox(height: 2),
                    AppText(
                      'Finding nearest airport',
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.25),
                      poppins: true,
                    ),
                  ] else if (isEmpty) ...[
                    AppText(
                      'Where to?',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.28),
                      poppins: true,
                      letterSpacing: -0.3,
                    ),
                    const SizedBox(height: 2),
                    AppText(
                      'Tap to select destination',
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.22),
                      poppins: true,
                    ),
                  ] else if (isCurrentLocation) ...[
                    AppText(
                      'Current location',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      poppins: true,
                      letterSpacing: -0.3,
                    ),
                    const SizedBox(height: 2),
                    AppText(
                      'Near ${airport!.city} · ${airport!.code}',
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.38),
                      poppins: true,
                    ),
                  ] else ...[
                    AppText(
                      airport!.city,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      poppins: true,
                      letterSpacing: -0.3,
                    ),
                    const SizedBox(height: 2),
                    AppText(
                      airport!.name,
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.38),
                      poppins: true,
                    ),
                  ],
                ],
              ),
            ),

            // Right badge / indicator
            if (isLoading)
              const SizedBox(width: 46)
            else if (isEmpty)
              Icon(Icons.add_circle_outline_rounded,
                  color: AppColors.amber.withValues(alpha: 0.50), size: 26)
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.35), width: 1),
                ),
                child: isCurrentLocation
                    ? const Icon(
                        Icons.gps_fixed_rounded,
                        size: 18,
                        color: AppColors.amber,
                      )
                    : AppText(
                        airport!.code,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.amber,
                        poppins: true,
                        letterSpacing: 0.5,
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
