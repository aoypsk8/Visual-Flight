import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_locale_utils.dart';
import 'app_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppFieldLabel
// EN → Menlo uppercase 10px   |   LO → GoogleFonts.notoSansLao 12px
// Reactive via Localizations.localeOf(context) InheritedWidget.
// ─────────────────────────────────────────────────────────────────────────────

class AppFieldLabel extends StatelessWidget {
  final String label;

  const AppFieldLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final isLao = isLaoLocale(context);
    return AppText(
      label,
      fontSize: isLao ? 12 : 10,
      fontWeight: FontWeight.w600,
      color: AppColors.tx3,
      mono: !isLao,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppTextField
//
// Drop-in animated text field with focus border hair2 → amber and icon tint.
//
// Usage (minimal):
//   AppTextField(hint: 'Email', icon: Icons.mail_outline_rounded)
//
// Usage (with label above + controller + validation):
//   AppTextField(
//     label: 'EMAIL ADDRESS',
//     hint: 'you@example.com',
//     icon: Icons.mail_outline_rounded,
//     controller: _emailCtrl,
//     keyboardType: TextInputType.emailAddress,
//     textInputAction: TextInputAction.next,
//     validator: (v) => v!.contains('@') ? null : 'Invalid email',
//   )
// ─────────────────────────────────────────────────────────────────────────────

class AppTextField extends StatefulWidget {
  /// Optional label rendered above the field in monospace uppercase.
  final String? label;

  /// Placeholder text inside the field.
  final String hint;

  /// Leading icon.
  final IconData icon;

  /// Password / obscure mode — adds eye toggle button.
  final bool obscure;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;

  const AppTextField({
    super.key,
    required this.hint,
    required this.icon,
    this.label,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.controller,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled = true,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField>
    with SingleTickerProviderStateMixin {
  late final FocusNode _focus;
  late final AnimationController _ctrl;
  late final Animation<Color?> _borderAnim;
  late final Animation<Color?> _iconAnim;
  bool _showText = false;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _borderAnim = ColorTween(
      begin: AppColors.hair2,
      end: AppColors.amber,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _iconAnim = ColorTween(
      begin: AppColors.tx3,
      end: AppColors.amber,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _focus.addListener(() {
      if (!mounted) return;
      _focus.hasFocus ? _ctrl.forward() : _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          AppFieldLabel(label: widget.label!),
          const SizedBox(height: 8),
        ],
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) {
            final border = _borderAnim.value ?? AppColors.hair2;
            final iconColor = _iconAnim.value ?? AppColors.tx3;
            final side = BorderSide(color: border, width: 1);
            final radius = BorderRadius.circular(14);

            final fieldStyle = AppText.styleOf(
              context,
              color: AppColors.tx1,
              fontSize: 16,
              letterSpacing: -0.2,
            );
            final hintStyle = AppText.styleOf(
              context,
              color: AppColors.tx3,
              fontSize: 15,
            );

            return TextFormField(
              focusNode: _focus,
              controller: widget.controller,
              obscureText: widget.obscure && !_showText,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              enabled: widget.enabled,
              onChanged: widget.onChanged,
              onFieldSubmitted: widget.onFieldSubmitted,
              validator: widget.validator,
              cursorColor: AppColors.amber,
              style: fieldStyle,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: hintStyle,
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Icon(widget.icon, color: iconColor, size: 20),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
                suffixIcon: widget.obscure
                    ? IconButton(
                        icon: Icon(
                          _showText
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          color: AppColors.tx3,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _showText = !_showText),
                      )
                    : null,
                filled: true,
                fillColor: widget.enabled
                    ? AppColors.surf2
                    : AppColors.surf2.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 18),
                border: OutlineInputBorder(
                    borderRadius: radius, borderSide: side),
                enabledBorder: OutlineInputBorder(
                    borderRadius: radius, borderSide: side),
                focusedBorder: OutlineInputBorder(
                    borderRadius: radius, borderSide: side),
                disabledBorder: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: BorderSide(
                      color: AppColors.hair, width: 1),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: const BorderSide(
                      color: Color(0xFFE05252), width: 1),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: const BorderSide(
                      color: Color(0xFFE05252), width: 1),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
