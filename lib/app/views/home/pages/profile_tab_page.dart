import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/theme_controller.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common/app_text.dart';

class ProfileTabPage extends StatelessWidget {
  const ProfileTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: AppText.title('Profile', color: colors.tx1),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _SettingsSection(
              label: 'APPEARANCE',
              children: [const _ThemeToggleRow()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Settings section wrapper ─────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _SettingsSection({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: AppText.label(label, color: colors.tx3),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.surf2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.hair2, width: 1),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ─── Theme toggle row ─────────────────────────────────────────────────────────

class _ThemeToggleRow extends StatelessWidget {
  const _ThemeToggleRow();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Obx(() {
      final ctrl   = ThemeController.to;
      final isDark = ctrl.isDark.value;

      return GestureDetector(
        onTap: ctrl.toggle,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.amberSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: AppColors.amber,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),

              // Label
              Expanded(
                child: AppText(
                  isDark ? 'Dark mode' : 'Light mode',
                  color: colors.tx1,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),

              // Animated toggle switch
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOut,
                width: 48,
                height: 28,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.amber : colors.surf3,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colors.hair2, width: 1),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeInOut,
                  alignment:
                      isDark ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
