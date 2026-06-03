import 'package:flutter/material.dart';
import '../../../../models/airport_model.dart';
import '../../../../utils/app_colors.dart';
import '../../../../widgets/common/app_text.dart';

class SearchAirportRow extends StatelessWidget {
  final String role;
  final Airport? airport;
  final IconData icon;
  final bool isTop;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isCurrentLocation;
  final bool emphasize;

  const SearchAirportRow({
    super.key,
    required this.role,
    required this.airport,
    required this.icon,
    required this.isTop,
    required this.onTap,
    this.isLoading = false,
    this.isCurrentLocation = false,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = airport == null && !isLoading;
    final isTo = role == 'TO';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: emphasize
              ? AppColors.amber.withValues(alpha: 0.06)
              : Colors.transparent,
          border: emphasize
              ? Border(
                  left: BorderSide(
                    color: AppColors.amber.withValues(alpha: 0.55),
                    width: 2,
                  ),
                )
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            emphasize ? 16 : 18,
            isTop ? 20 : 14,
            18,
            isTop ? 14 : 20,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: emphasize ? 0.08 : 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: emphasize
                        ? AppColors.amber.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: isEmpty && !emphasize
                      ? Colors.white.withValues(alpha: 0.20)
                      : emphasize
                          ? AppColors.amber.withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.50),
                ),
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
                      color: emphasize
                          ? AppColors.amber.withValues(alpha: 0.75)
                          : Colors.white.withValues(alpha: 0.35),
                      letterSpacing: 1.5,
                      poppins: true,
                    ),
                    const SizedBox(height: 3),
                    if (isLoading) ...[
                      Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
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
                        ],
                      ),
                      const SizedBox(height: 2),
                      AppText(
                        'Finding nearest airport',
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.25),
                        poppins: true,
                      ),
                    ] else if (isEmpty) ...[
                      AppText(
                        isTo ? 'Where to?' : 'Set departure',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: emphasize
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.28),
                        poppins: true,
                        letterSpacing: -0.3,
                      ),
                      const SizedBox(height: 2),
                      AppText(
                        isTo
                            ? 'Search city or airport code'
                            : 'Uses your location by default',
                        fontSize: 11,
                        color: Colors.white.withValues(
                          alpha: emphasize ? 0.45 : 0.22,
                        ),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(width: 46)
              else if (isEmpty)
                Icon(
                  emphasize ? Icons.arrow_forward_rounded : Icons.add_rounded,
                  color: AppColors.amber.withValues(alpha: emphasize ? 0.9 : 0.5),
                  size: emphasize ? 22 : 24,
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.35),
                    ),
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
      ),
    );
  }
}
