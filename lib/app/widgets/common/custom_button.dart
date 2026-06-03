import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_resources.dart';
import 'app_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppPrimaryButton
//
// Full-width pill button. White fill, dark text, amber glow shadow.
// Press scales to 0.97. Shows a circular progress indicator when loading.
//
// Usage:
//   AppPrimaryButton(label: 'Sign in', onTap: _handleSignIn)
//   AppPrimaryButton(label: 'Create account', onTap: _submit, loading: controller.isLoading)
// ─────────────────────────────────────────────────────────────────────────────

class AppPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.loading = false,
  });

  @override
  State<AppPrimaryButton> createState() => _AppPrimaryButtonState();
}

class _AppPrimaryButtonState extends State<AppPrimaryButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final active = !widget.loading && widget.onTap != null;

    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _down = true) : null,
      onTapUp: active ? (_) => setState(() => _down = false) : null,
      onTapCancel: active ? () => setState(() => _down = false) : null,
      onTap: active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: AnimatedOpacity(
          opacity: active ? 1.0 : 0.6,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.tx1,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF0A0B0D),
                      ),
                    )
                  : AppText(
                      widget.label,
                      color: const Color(0xFF0A0B0D),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppSocialButton
//
// Outlined dark button for OAuth providers (Google, Apple, etc.)
//
// Usage:
//   AppSocialButton(iconAsset: AppIcons.google, label: 'Google', onTap: _signInGoogle)
//   AppSocialButton(iconAsset: AppIcons.apple, label: 'Apple', onTap: _signInApple)
// ─────────────────────────────────────────────────────────────────────────────

class AppSocialButton extends StatefulWidget {
  final IconData? icon;
  final String? iconAsset;
  final String label;
  final VoidCallback? onTap;

  const AppSocialButton({
    super.key,
    this.icon,
    this.iconAsset,
    required this.label,
    this.onTap,
  }) : assert(
          icon != null || iconAsset != null,
          'Provide icon or iconAsset',
        );

  static const double iconSize = 20;

  @override
  State<AppSocialButton> createState() => _AppSocialButtonState();
}

class _AppSocialButtonState extends State<AppSocialButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.surf2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.hair2, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SocialIcon(
                icon: widget.icon,
                iconAsset: widget.iconAsset,
                size: AppSocialButton.iconSize,
              ),
              const SizedBox(width: 8),
              AppText(
                widget.label,
                color: AppColors.tx2,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final IconData? icon;
  final String? iconAsset;
  final double size;

  const _SocialIcon({
    required this.icon,
    required this.iconAsset,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (iconAsset != null) {
      return SvgPicture.asset(
        iconAsset!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticsLabel: iconAsset,
        placeholderBuilder: (_) => SizedBox(
          width: size,
          height: size,
          child: const Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorBuilder: (context, error, _) => Icon(
          _fallbackIconData(iconAsset!),
          color: AppColors.tx2,
          size: size,
        ),
      );
    }
    return Icon(icon, color: AppColors.tx2, size: size);
  }

  static IconData _fallbackIconData(String asset) {
    if (asset == AppIcons.apple) return Icons.apple_rounded;
    if (asset == AppIcons.github) return Icons.code_rounded;
    return Icons.g_mobiledata_rounded;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppOrDivider
//
// Hairline divider with a centered label. Defaults to 'or continue with'.
//
// Usage:
//   const AppOrDivider()
//   AppOrDivider(label: 'or')
// ─────────────────────────────────────────────────────────────────────────────

class AppOrDivider extends StatelessWidget {
  final String label;

  const AppOrDivider({super.key, this.label = 'or continue with'});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.hair)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: AppText(
            label,
            color: AppColors.tx3,
            fontSize: 11,
            letterSpacing: 0.2,
          ),
        ),
        Expanded(child: Container(height: 1, color: AppColors.hair)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppAmberBlob
//
// Soft ambient glow blob positioned absolutely. Wrap in an AnimatedBuilder
// for oscillating movement.
//
// Usage inside a Stack:
//   AppAmberBlob(x: size.width * 0.25, y: -80, radius: 220, opacity: 0.13)
// ─────────────────────────────────────────────────────────────────────────────

class AppAmberBlob extends StatelessWidget {
  final double x, y, radius, opacity;

  const AppAmberBlob({
    super.key,
    required this.x,
    required this.y,
    required this.radius,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x - radius,
      top: y - radius,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.amber.withValues(alpha: opacity),
              blurRadius: radius * 1.2,
              spreadRadius: radius * 0.4,
            ),
          ],
        ),
      ),
    );
  }
}
