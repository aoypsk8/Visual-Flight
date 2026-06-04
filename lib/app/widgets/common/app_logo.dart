import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../config/app_branding.dart';
import '../../utils/app_colors.dart';
import 'app_text.dart';

/// โลโก้ Dingocoin + ชื่อแอป (รองรับ i18n ผ่าน [brand_focusflight])
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 32,
    this.showLabel = false,
    this.labelColor = AppColors.amber,
    this.bordered = false,
    this.labelFontSize,
    this.labelPoppins = false,
  });

  final double size;
  final bool showLabel;
  final Color labelColor;
  final bool bordered;

  /// ถ้ากำหนด จะใช้สไตล์หัวข้อแทน label ตัวเล็ก (เช่น หน้า Search)
  final double? labelFontSize;
  final bool labelPoppins;

  @override
  Widget build(BuildContext context) {
    final icon = SvgPicture.asset(
      AppBranding.logoAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticsLabel: AppBranding.appName,
    );

    Widget logo = icon;
    if (bordered) {
      logo = Container(
        padding: EdgeInsets.all(size * 0.12),
        decoration: BoxDecoration(
          color: AppColors.amberSoft,
          borderRadius: BorderRadius.circular(size * 0.22),
        ),
        child: icon,
      );
    }

    if (!showLabel) return logo;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        SizedBox(width: size * 0.28),
        Flexible(
          child: labelFontSize != null
              ? AppText(
                  'brand_focusflight'.tr,
                  color: labelColor,
                  fontSize: labelFontSize!,
                  fontWeight: FontWeight.w700,
                  poppins: labelPoppins,
                  maxLines: 1,
                )
              : AppText.label(
                  'brand_focusflight'.tr,
                  color: labelColor,
                  maxLines: 1,
                ),
        ),
      ],
    );
  }
}
