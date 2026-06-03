import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/locale_controller.dart';
import '../../utils/app_colors.dart';
import 'app_text.dart';
import 'locale_reactive.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppLanguageSheet.show(context)
// ─────────────────────────────────────────────────────────────────────────────

class AppLanguageSheet {
  const AppLanguageSheet._();

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isScrollControlled: false,
      builder: (sheetContext) => LocaleReactive(
        builder: (_) => _LanguageSheetBody(sheetContext: sheetContext),
      ),
    );
  }
}

class _LanguageSheetBody extends StatelessWidget {
  final BuildContext sheetContext;

  const _LanguageSheetBody({required this.sheetContext});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(sheetContext).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surf2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: AppColors.hair2, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AppText.label(
              'language_sheet_title'.tr,
              color: AppColors.tx3,
            ),
          ),
          const SizedBox(height: 14),

          Obx(() {
            final ctrl = LocaleController.to;
            final locales = LocaleController.supported;
            return Column(
              children: [
                for (var i = 0; i < locales.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.only(left: 24),
                      child: Divider(height: 1, color: AppColors.hair),
                    ),
                  _LocaleRow(
                    locale: locales[i],
                    isActive: locales[i].code ==
                        ctrl.current.value.languageCode,
                    onTap: () {
                      ctrl.changeLocale(locales[i].code);
                      Get.back();
                    },
                  ),
                ],
              ],
            );
          }),

          SizedBox(height: 12 + bottom),
        ],
      ),
    );
  }
}

class _LocaleRow extends StatelessWidget {
  final AppLocale locale;
  final bool isActive;
  final VoidCallback onTap;

  const _LocaleRow({
    required this.locale,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.hair,
        highlightColor: AppColors.hair,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 15, 24, 15),
          child: Row(
            children: [
              // Left bar indicates current selection — not the entire row card
              Container(
                width: 2,
                height: 18,
                color: isActive ? AppColors.amber : Colors.transparent,
              ),
              const SizedBox(width: 12),
              _LocaleFlag(countryCode: locale.country),
              const SizedBox(width: 14),
              Expanded(
                child: AppText(
                  locale.nativeLabel,
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  poppins: locale.code == 'en',
                  noto: locale.code == 'lo',
                  color: isActive ? AppColors.tx1 : AppColors.tx2,
                ),
              ),
              if (isActive)
                const _ActiveMark()
              else
                const SizedBox(width: 6, height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocaleFlag extends StatelessWidget {
  final String countryCode;

  const _LocaleFlag({required this.countryCode});

  @override
  Widget build(BuildContext context) {
    return CountryFlag.fromCountryCode(
      countryCode,
      theme: const ImageTheme(
        width: 28,
        height: 20,
        shape: RoundedRectangle(4),
      ),
    );
  }
}

/// Small dot replacing the amber circle + check
class _ActiveMark extends StatelessWidget {
  const _ActiveMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: AppColors.amber,
        shape: BoxShape.circle,
      ),
    );
  }
}
