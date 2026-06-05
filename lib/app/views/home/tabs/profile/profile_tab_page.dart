import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../widgets/common/locale_reactive.dart';

import '../../../../controllers/theme_controller.dart';
import '../../../../services/auth_service.dart';
import '../../../../utils/app_theme.dart';
import '../../../../widgets/common/app_language_toggle.dart';
import '../../../../widgets/common/app_text.dart';

/// Profile — simple, personal settings (no marketing chrome).
class ProfileTabPage extends StatelessWidget {
  const ProfileTabPage({super.key});

  static const _appVersion = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomInset = MediaQuery.paddingOf(context).bottom + 108;

    return LocaleReactive(
      builder: (context) => ColoredBox(
      color: colors.surf1,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Obx(() {
                    final user = AuthService.to.user.value!;
                    return _ProfileIntro(
                      greeting: _greeting(),
                      name: user.greetingName,
                      email: user.email,
                    );
                  }),
                  const SizedBox(height: 32),
                  _GroupLabel('profile_preferences'.tr, colors: colors),
                  const SizedBox(height: 8),
                  _SettingsGroup(
                    colors: colors,
                    children: const [
                      _DarkModeRow(),
                      _Hairline(),
                      _LanguageRow(),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Obx(() {
                    final user = AuthService.to.user.value!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GroupLabel('profile_your_account'.tr, colors: colors),
                        const SizedBox(height: 8),
                        _SettingsGroup(
                          colors: colors,
                          children: [
                            if (user.name.trim().isNotEmpty) ...[
                              _StaticRow(
                                title: user.name,
                                hint: 'profile_full_name'.tr,
                              ),
                              const _Hairline(),
                            ],
                            if (user.firstName.trim().isNotEmpty) ...[
                              _StaticRow(
                                title: user.firstName,
                                hint: 'profile_first_name'.tr,
                              ),
                              const _Hairline(),
                            ],
                            if (user.lastName.trim().isNotEmpty) ...[
                              _StaticRow(
                                title: user.lastName,
                                hint: 'profile_last_name'.tr,
                              ),
                              const _Hairline(),
                            ],
                            _StaticRow(
                              title: user.email,
                              hint: 'profile_email'.tr,
                            ),
                            const _Hairline(),
                            _TappableRow(
                                title: 'profile_logout'.tr,
                              titleColor: colors.isDark
                                  ? const Color(0xFFFF8A8A)
                                  : const Color(0xFFC62828),
                              onTap: () async {
                                HapticFeedback.lightImpact();
                                await AuthService.to.logout();
                              },
                            ),
                          ],
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 28),
                  _ShowcaseSection(colors: colors),
                  const SizedBox(height: 40),
                  Center(
                    child: AppText(
                      'profile_version'.trParams({'version': _appVersion}),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.tx3,
                      poppins: true,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'profile_good_morning'.tr;
    if (hour < 17) return 'profile_good_afternoon'.tr;
    return 'profile_good_evening'.tr;
  }

}

// ─── Intro (left-aligned, no hero card) ─────────────────────────────────────

class _ProfileIntro extends StatelessWidget {
  const _ProfileIntro({
    required this.greeting,
    required this.name,
    required this.email,
  });

  final String greeting;
  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final initial =
        name.isNotEmpty ? name[0].toUpperCase() : (email.isNotEmpty ? email[0].toUpperCase() : '?');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(initial: initial, colors: colors),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                greeting,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colors.tx2,
                poppins: true,
              ),
              const SizedBox(height: 4),
              AppText(
                'profile_hi'.trParams({'name': name}),
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: colors.tx1,
                poppins: true,
                letterSpacing: -0.6,
                height: 1.15,
              ),
              const SizedBox(height: 10),
              AppText(
                email,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: colors.tx2,
                height: 1.45,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.colors});

  final String initial;
  final AppTheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: colors.surf3,
        shape: BoxShape.circle,
        border: Border.all(color: colors.hair2),
      ),
      alignment: Alignment.center,
      child: AppText(
        initial,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: colors.tx2,
        poppins: true,
      ),
    );
  }
}

// ─── Grouped settings (iOS-like, flat) ────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text, {required this.colors});

  final String text;
  final AppTheme colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: AppText(
        text,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: colors.tx3,
        poppins: true,
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.colors,
    required this.children,
  });

  final AppTheme colors;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surf2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.hair),
      ),
      child: Column(children: children),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: context.colors.hair,
    );
  }
}

// ─── Rows ─────────────────────────────────────────────────────────────────────

class _DarkModeRow extends StatelessWidget {
  const _DarkModeRow();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Obx(() {
      final isDark = ThemeController.to.isDark.value;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    'profile_dark_mode'.tr,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: colors.tx1,
                    poppins: true,
                  ),
                  const SizedBox(height: 2),
                  AppText(
                    isDark
                        ? 'profile_dark_hint_on'.tr
                        : 'profile_dark_hint_off'.tr,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: colors.tx3,
                    poppins: true,
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: isDark,
              activeTrackColor: colors.amber.withValues(alpha: 0.55),
              activeThumbColor: colors.amber,
              onChanged: (_) {
                HapticFeedback.selectionClick();
                ThemeController.to.toggle();
              },
            ),
          ],
        ),
      );
    });
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'profile_language'.tr,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: colors.tx1,
                  poppins: true,
                ),
                const SizedBox(height: 2),
                AppText(
                  'profile_language_hint'.tr,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: colors.tx3,
                  poppins: true,
                ),
              ],
            ),
          ),
          const AppLanguageToggle(),
        ],
      ),
    );
  }
}

class _TappableRow extends StatelessWidget {
  const _TappableRow({
    required this.title,
    this.hint,
    this.titleColor,
    required this.onTap,
  });

  final String title;
  final String? hint;
  final Color? titleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      title,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: titleColor ?? colors.tx1,
                      poppins: true,
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 3),
                      AppText(
                        hint!,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: colors.tx3,
                        poppins: true,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 22, color: colors.tx3),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── App Showcase ─────────────────────────────────────────────────────────────

class _ShowcaseSection extends StatelessWidget {
  const _ShowcaseSection({required this.colors});

  final AppTheme colors;

  static const _images = [
    'assets/showcase/Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-06-05 at 09.10.23.png',
    'assets/showcase/Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-06-05 at 09.10.26.png',
    'assets/showcase/Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-06-05 at 09.10.29.png',
    'assets/showcase/Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-06-05 at 09.10.31.png',
    'assets/showcase/Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-06-05 at 09.10.33.png',
    'assets/showcase/Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-06-05 at 09.11.01.png',
    'assets/showcase/Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-06-05 at 09.11.10.png',
    'assets/showcase/Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-06-05 at 09.11.18.png',
    'assets/showcase/Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-06-05 at 09.11.22.png',
    'assets/showcase/Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-06-05 at 09.11.30.png',
    'assets/showcase/Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-06-05 at 09.11.34.png',
    'assets/showcase/Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-06-05 at 09.11.36.png',
    'assets/showcase/Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-06-05 at 09.11.40.png',
    'assets/showcase/Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-06-05 at 09.11.44.png',
    'assets/showcase/Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-06-05 at 09.11.50.png',
    'assets/showcase/Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-06-05 at 09.11.53.png',
    'assets/showcase/Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-06-05 at 09.11.55.png',
    'assets/showcase/Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-06-05 at 09.12.03.png',
    'assets/showcase/Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-06-05 at 09.12.15.png',
    'assets/showcase/Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-06-05 at 09.12.24.png',
    'assets/showcase/Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-06-05 at 09.12.26.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GroupLabel('profile_showcase'.tr, colors: colors),
        const SizedBox(height: 8),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: _images.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (_, i) => Container(
              width: 187,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.hair2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Image.asset(
                  _images[i],
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StaticRow extends StatelessWidget {
  const _StaticRow({required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            title,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: colors.tx1,
            poppins: true,
          ),
          if (hint != null) ...[
            const SizedBox(height: 3),
            AppText(
              hint!,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: colors.tx3,
              poppins: true,
            ),
          ],
        ],
      ),
    );
  }
}
