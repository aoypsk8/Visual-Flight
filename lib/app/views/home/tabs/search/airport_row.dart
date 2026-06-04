import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../models/airport_model.dart';
import '../../../../utils/app_colors.dart';
import '../../../../widgets/common/app_text.dart';

class SearchAirportRow extends StatelessWidget {
  final String roleKey;
  final Airport? airport;
  final IconData icon;
  final bool isTop;
  final VoidCallback onTap;
  final VoidCallback? onPinTap;
  final VoidCallback? onAltTap;
  final IconData? altIcon;
  final bool isLoading;
  final bool isCurrentLocation;
  final bool isMapPin;
  final bool emphasize;
  final bool pinningOnMap;

  const SearchAirportRow({
    super.key,
    required this.roleKey,
    required this.airport,
    required this.icon,
    required this.isTop,
    required this.onTap,
    this.onPinTap,
    this.onAltTap,
    this.altIcon,
    this.isLoading = false,
    this.isCurrentLocation = false,
    this.isMapPin = false,
    this.emphasize = false,
    this.pinningOnMap = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = airport == null && !isLoading;
    final isTo = roleKey == 'search_role_to';

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
            emphasize ? 14 : 16,
            isTop ? 14 : 10,
            14,
            isTop ? 10 : 14,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: emphasize ? 0.08 : 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: emphasize
                        ? AppColors.amber.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isEmpty && !emphasize
                      ? Colors.white.withValues(alpha: 0.20)
                      : emphasize
                          ? AppColors.amber.withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      roleKey.tr,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: emphasize
                          ? AppColors.amber.withValues(alpha: 0.75)
                          : Colors.white.withValues(alpha: 0.35),
                      letterSpacing: 1.5,
                      poppins: true,
                    ),
                    const SizedBox(height: 2),
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
                            'search_detecting_location'.tr,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.45),
                            poppins: true,
                          ),
                        ],
                      ),
                    ] else if (isEmpty) ...[
                      AppText(
                        isTo
                            ? 'search_where_to'.tr
                            : 'search_set_departure'.tr,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: emphasize
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.28),
                        poppins: true,
                        letterSpacing: -0.3,
                      ),
                      AppText(
                        isTo
                            ? 'search_search_city_hint'.tr
                            : 'search_uses_location_default'.tr,
                        fontSize: 11,
                        color: Colors.white.withValues(
                          alpha: emphasize ? 0.45 : 0.22,
                        ),
                        poppins: true,
                      ),
                    ] else if (isMapPin) ...[
                      AppText(
                        'search_pinned_on_map'.tr,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        poppins: true,
                      ),
                      AppText(
                        'search_near_city_code'.trParams({
                          'city': airport!.city,
                          'code': airport!.code,
                        }),
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.38),
                        poppins: true,
                      ),
                    ] else if (isCurrentLocation) ...[
                      AppText(
                        'search_current_location'.tr,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        poppins: true,
                      ),
                      AppText(
                        'search_near_city_code'.trParams({
                          'city': airport!.city,
                          'code': airport!.code,
                        }),
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.38),
                        poppins: true,
                      ),
                    ] else ...[
                      AppText(
                        airport!.city,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        poppins: true,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
              if (!isLoading) ...[
                if (onPinTap != null) ...[
                  _RowIconButton(
                    icon: Icons.push_pin_outlined,
                    active: pinningOnMap,
                    tooltip: 'search_action_pin'.tr,
                    onTap: onPinTap!,
                  ),
                  const SizedBox(width: 4),
                ],
                if (onAltTap != null && altIcon != null) ...[
                  _RowIconButton(
                    icon: altIcon!,
                    tooltip: altIcon == Icons.near_me_outlined
                        ? 'search_action_my_location'.tr
                        : 'search_action_search'.tr,
                    onTap: onAltTap!,
                  ),
                  const SizedBox(width: 4),
                ],
                if (isEmpty)
                  Icon(
                    emphasize
                        ? Icons.arrow_forward_rounded
                        : Icons.add_rounded,
                    color:
                        AppColors.amber.withValues(alpha: emphasize ? 0.9 : 0.5),
                    size: emphasize ? 22 : 24,
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.amber.withValues(alpha: 0.35),
                      ),
                    ),
                    child: isCurrentLocation
                        ? const Icon(
                            Icons.gps_fixed_rounded,
                            size: 16,
                            color: AppColors.amber,
                          )
                        : isMapPin
                            ? const Icon(
                                Icons.push_pin_rounded,
                                size: 16,
                                color: AppColors.amber,
                              )
                            : AppText(
                                airport!.code,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.amber,
                                poppins: true,
                              ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RowIconButton extends StatelessWidget {
  const _RowIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.amber.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active
                    ? AppColors.amber.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Icon(
              icon,
              size: 16,
              color: active
                  ? AppColors.amber
                  : Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}
