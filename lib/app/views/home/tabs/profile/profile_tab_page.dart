import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../controllers/theme_controller.dart';
import '../../../../routes/app_routes.dart';
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

    return ColoredBox(
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
                    final user = AuthService.to.user.value;
                    final firstName = _firstName(user?.name);
                    return _ProfileIntro(
                      greeting: _greeting(),
                      name: firstName,
                      email: user?.email,
                      isGuest: user == null,
                    );
                  }),
                  const SizedBox(height: 32),
                  _GroupLabel('Preferences', colors: colors),
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
                    final loggedIn = AuthService.to.isLoggedIn;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GroupLabel(
                          loggedIn ? 'Your account' : 'Account',
                          colors: colors,
                        ),
                        const SizedBox(height: 8),
                        _SettingsGroup(
                          colors: colors,
                          children: [
                            if (!loggedIn)
                              _TappableRow(
                                title: 'Log in',
                                hint: 'Optional — for saving trips later',
                                onTap: () => Get.toNamed(AppRoutes.login),
                              )
                            else ...[
                              _StaticRow(
                                title: AuthService.to.user.value?.email ?? '',
                                hint: 'This is where you’re signed in',
                              ),
                              const _Hairline(),
                              _TappableRow(
                                title: 'Log out',
                                titleColor: colors.isDark
                                    ? const Color(0xFFFF8A8A)
                                    : const Color(0xFFC62828),
                                onTap: () async {
                                  HapticFeedback.lightImpact();
                                  await AuthService.to.logout();
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 40),
                  Center(
                    child: AppText(
                      'FocusFlight · $_appVersion',
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
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String _firstName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return 'there';
    return fullName.trim().split(RegExp(r'\s+')).first;
  }
}

// ─── Intro (left-aligned, no hero card) ─────────────────────────────────────

class _ProfileIntro extends StatelessWidget {
  const _ProfileIntro({
    required this.greeting,
    required this.name,
    required this.email,
    required this.isGuest,
  });

  final String greeting;
  final String name;
  final String? email;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(initial: isGuest ? '?' : name[0].toUpperCase(), colors: colors),
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
                isGuest ? 'Hi $name' : 'Hi, $name',
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: colors.tx1,
                poppins: true,
                letterSpacing: -0.6,
                height: 1.15,
              ),
              const SizedBox(height: 10),
              AppText(
                isGuest
                    ? 'You’re here as a guest. Nothing to set up — just pick a route when you’re ready.'
                    : (email ?? ''),
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
                    'Dark mode',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: colors.tx1,
                    poppins: true,
                  ),
                  const SizedBox(height: 2),
                  AppText(
                    isDark ? 'Easier at night' : 'Brighter during the day',
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
                  'Language',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: colors.tx1,
                  poppins: true,
                ),
                const SizedBox(height: 2),
                AppText(
                  'English or Lao',
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
