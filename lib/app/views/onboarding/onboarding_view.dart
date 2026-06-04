import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/app_local_storage.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../routes/app_routes.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_resources.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common/common.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Slide data — all text fields are translation keys, call .tr when rendering
// ─────────────────────────────────────────────────────────────────────────────

class _Slide {
  final String lottie;
  final String tagKey;
  final String titleKey;
  final String bodyKey;
  final Permission permission;
  final String allowKey;
  final String popupTitleKey;

  const _Slide({
    required this.lottie,
    required this.tagKey,
    required this.titleKey,
    required this.bodyKey,
    required this.permission,
    required this.allowKey,
    required this.popupTitleKey,
  });
}

const _slides = [
  _Slide(
    lottie: AppLottie.location,
    tagKey: 'ob_tag_location',
    titleKey: 'ob_title_location',
    bodyKey: 'ob_body_location',
    permission: Permission.locationWhenInUse,
    allowKey: 'ob_allow_location',
    popupTitleKey: 'ob_popup_location',
  ),
  _Slide(
    lottie: AppLottie.camera,
    tagKey: 'ob_tag_camera',
    titleKey: 'ob_title_camera',
    bodyKey: 'ob_body_camera',
    permission: Permission.camera,
    allowKey: 'ob_allow_camera',
    popupTitleKey: 'ob_popup_camera',
  ),
  _Slide(
    lottie: AppLottie.gallery,
    tagKey: 'ob_tag_photos',
    titleKey: 'ob_title_photos',
    bodyKey: 'ob_body_photos',
    permission: Permission.photos,
    allowKey: 'ob_allow_photos',
    popupTitleKey: 'ob_popup_photos',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// OnboardingView
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleAllow() async {
    final slide = _slides[_currentIndex];
    final result = await _showPermissionSheet(slide);

    // null = user tapped outside the popup → just dismiss, stay on same slide
    if (result == null) return;

    if (result == true) {
      await slide.permission.request();
    }

    if (!mounted) return;
    _advance();
  }

  void _advance() {
    if (_currentIndex < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    AppLocalStorage.writeBool('onboarding_done', true);
    Get.offNamed(AppRoutes.login);
  }

  Future<bool?> _showPermissionSheet(_Slide slide) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: slide.tagKey.tr,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 480),
      transitionBuilder: (ctx, anim, secondAnim, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.55),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, anim, secondAnim) => _PermissionSheet(slide: slide),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LocaleReactive(
      builder: (context) {
        final colors = context.colors;
        final isLast = _currentIndex == _slides.length - 1;
        final slide = _slides[_currentIndex];

        return Scaffold(
          backgroundColor: colors.surf1,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: -40,
                top: -60,
                child: _StaticBlob(
                  radius: 200,
                  color: colors.amber.withValues(alpha: 0.07),
                ),
              ),
              Positioned(
                right: -60,
                bottom: 80,
                child: _StaticBlob(
                  radius: 160,
                  color: colors.amber.withValues(alpha: 0.05),
                ),
              ),

              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Top bar ────────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: colors.amberSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: AppText.label(
                              'FocusFlight',
                              color: colors.amber,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => AppLanguageSheet.show(context),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: colors.surf3,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: colors.hair,
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.language_rounded,
                                color: colors.tx2,
                                size: 18,
                              ),
                            ),
                          ),
                          if (!isLast) ...[
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _finish,
                              style: TextButton.styleFrom(
                                foregroundColor: colors.tx3,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              child: AppText(
                                'ob_skip'.tr,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colors.tx3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ── Slide pages ──────────────────────────────────────────
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: (i) =>
                            setState(() => _currentIndex = i),
                        itemCount: _slides.length,
                        itemBuilder: (_, i) => _SlidePage(
                          slide: _slides[i],
                          index: i,
                          total: _slides.length,
                        ),
                      ),
                    ),

                    // ── Bottom actions ────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _DotIndicator(
                            count: _slides.length,
                            current: _currentIndex,
                            colors: colors,
                          ),
                          const SizedBox(height: 24),
                          AppPrimaryButton(
                            label: isLast
                                ? 'ob_get_started'.tr
                                : slide.allowKey.tr,
                            onTap: _handleAllow,
                          ),
                          const SizedBox(height: 12),
                          AppText.caption(
                            'ob_settings_hint'.tr,
                            textAlign: TextAlign.center,
                            color: colors.tx3,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide page — big frameless Lottie
// ─────────────────────────────────────────────────────────────────────────────

class _SlidePage extends StatelessWidget {
  final _Slide slide;
  final int index;
  final int total;

  const _SlidePage({
    required this.slide,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final screenH = MediaQuery.of(context).size.height;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Big frameless Lottie
          SizedBox(
            width: double.infinity,
            height: screenH * 0.42,
            child: Lottie.asset(
              slide.lottie,
              fit: BoxFit.contain,
              repeat: true,
              frameRate: FrameRate.max,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.flight_rounded,
                size: 80,
                color: colors.amber.withValues(alpha: 0.5),
              ),
            ),
          ),

          const SizedBox(height: 20),

          AppText.headline(
            slide.titleKey.tr,
            textAlign: TextAlign.center,
            color: colors.tx1,
          ),
          const SizedBox(height: 14),

          AppText.body(
            slide.bodyKey.tr,
            textAlign: TextAlign.center,
            color: colors.tx2,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Permission popup — Lottie overflows the top of the card
// ─────────────────────────────────────────────────────────────────────────────

class _PermissionSheet extends StatelessWidget {
  final _Slide slide;
  const _PermissionSheet({required this.slide});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 20),
        child: Material(
          color: Colors.transparent,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // ── Card ──────────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.only(top: 72),
                padding: const EdgeInsets.fromLTRB(24, 72, 24, 28),
                decoration: BoxDecoration(
                  color: colors.surf2,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: colors.hair2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 48,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tag badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.amberSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AppText.label(
                        slide.tagKey.tr,
                        color: colors.amber,
                      ),
                    ),
                    const SizedBox(height: 14),

                    AppText.title(
                      slide.popupTitleKey.tr,
                      textAlign: TextAlign.center,
                      color: colors.tx1,
                    ),
                    const SizedBox(height: 10),

                    AppText.body(
                      slide.bodyKey.tr,
                      textAlign: TextAlign.center,
                      color: colors.tx2,
                    ),
                    const SizedBox(height: 28),

                    AppPrimaryButton(
                      label: slide.allowKey.tr,
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                    const SizedBox(height: 4),

                    // "Not now" — pops false so _handleAllow advances the slide
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.tx3,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      child: AppText(
                        'ob_not_now'.tr,
                        color: colors.tx3,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Lottie overflowing the card top ──────────────────────────
              Positioned(
                top: 0,
                child: Container(
                  width: 144,
                  height: 144,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surf3,
                    border: Border.all(color: colors.hair2, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.amber.withValues(alpha: 0.05),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Lottie.asset(
                      slide.lottie,
                      fit: BoxFit.cover,
                      repeat: true,
                      frameRate: FrameRate.max,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dot indicator
// ─────────────────────────────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  final int count;
  final int current;
  final AppTheme colors;

  const _DotIndicator({
    required this.count,
    required this.current,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 28 : 7,
          height: 7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: active ? colors.amber : colors.hair2,
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Static ambient glow blob
// ─────────────────────────────────────────────────────────────────────────────

class _StaticBlob extends StatelessWidget {
  final double radius;
  final Color color;
  const _StaticBlob({required this.radius, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: radius * 1.8,
            spreadRadius: radius * 0.8,
          ),
        ],
      ),
    );
  }
}
