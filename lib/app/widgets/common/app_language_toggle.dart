import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/locale_controller.dart';
import '../../utils/app_colors.dart';
import 'app_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppLanguageToggle
//
// Compact inline toggle showing supported locales.
// Tapping a pill switches the app language instantly (persisted via GetStorage).
//
// Usage:
//   const AppLanguageToggle()          // default horizontal row
//   AppLanguageToggle(compact: true)   // single pill that shows active lang
// ─────────────────────────────────────────────────────────────────────────────

class AppLanguageToggle extends StatelessWidget {
  /// When true shows only the active language — tap cycles to next.
  final bool compact;

  const AppLanguageToggle({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ctrl = LocaleController.to;
      final active = ctrl.current.value.languageCode;

      if (compact) {
        final current = LocaleController.supported
            .firstWhere((l) => l.code == active,
                orElse: () => LocaleController.supported.first);
        return GestureDetector(
          onTap: ctrl.toggle,
          child: _Pill(label: current.label, active: true),
        );
      }

      return Container(
        decoration: BoxDecoration(
          color: AppColors.surf3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.hair, width: 1),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: LocaleController.supported.map((locale) {
            final isActive = locale.code == active;
            return GestureDetector(
              onTap: () => ctrl.changeLocale(locale.code),
              child: _Pill(label: locale.label, active: isActive),
            );
          }).toList(),
        ),
      );
    });
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool active;

  const _Pill({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: active ? AppColors.amber : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
      ),
      child: AppText(
        label,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        poppins: true,
        color: active ? const Color(0xFF0A0B0D) : AppColors.tx3,
      ),
    );
  }
}
