import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/locale_controller.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_fonts.dart';
import '../../utils/app_locale_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppText
//
// Uses Google Fonts (internet) — no local font files needed.
// Font detection via Localizations.localeOf(context): reactive InheritedWidget
// that rebuilds this widget whenever GetMaterialApp.locale changes.
//
//   EN → Poppins (Google Fonts)
//   LO → Noto Sans Lao (ทุกข้อความ แม้ตั้ง poppins: true)
//   mono → Menlo (เฉพาะ EN)
//
// Usage:
//   AppText('Hello')
//   AppText.headline('Welcome back.')
//   AppText.body('Subtitle.', color: AppColors.tx2)
//   AppText.label('EMAIL ADDRESS')
//   AppText.caption('Min 8 chars.')
//   AppText.amber('FocusFlight')
// ─────────────────────────────────────────────────────────────────────────────

class AppText extends StatelessWidget {
  /// Enable font logging in debug mode (disable if logs become too noisy)
  static bool logFontResolution = true;

  /// true = log on every build, false = log only new combinations
  static bool logEveryBuild = false;

  final String text;
  final bool poppins;
  final bool noto;
  final bool mono;
  final TextAlign textAlign;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final int? maxLines;
  final bool underline;
  final Color underlineColor;
  final double? letterSpacing;
  final double? height;
  final TextOverflow overflow;
  final bool softWrap;

  // ── Default ────────────────────────────────────────────────────────────────

  const AppText(
    this.text, {
    super.key,
    this.poppins = false,
    this.noto = false,
    this.mono = false,
    this.textAlign = TextAlign.start,
    this.color = AppColors.tx1,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w400,
    this.maxLines,
    this.underline = false,
    this.underlineColor = AppColors.tx3,
    this.letterSpacing,
    this.height,
    this.overflow = TextOverflow.ellipsis,
    this.softWrap = true,
  });

  // ── Semantic constructors ──────────────────────────────────────────────────

  const AppText.headline(
    this.text, {
    super.key,
    this.color = AppColors.tx1,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
    this.softWrap = true,
  })  : poppins = false,
        noto = false,
        mono = false,
        fontSize = 34,
        fontWeight = FontWeight.w700,
        underline = false,
        underlineColor = AppColors.tx3,
        letterSpacing = -1.2,
        height = 1.08;

  const AppText.title(
    this.text, {
    super.key,
    this.color = AppColors.tx1,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
    this.softWrap = true,
  })  : poppins = false,
        noto = false,
        mono = false,
        fontSize = 22,
        fontWeight = FontWeight.w600,
        underline = false,
        underlineColor = AppColors.tx3,
        letterSpacing = -0.6,
        height = 1.2;

  const AppText.body(
    this.text, {
    super.key,
    this.color = AppColors.tx2,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
    this.softWrap = true,
  })  : poppins = false,
        noto = false,
        mono = false,
        fontSize = 15,
        fontWeight = FontWeight.w400,
        underline = false,
        underlineColor = AppColors.tx3,
        letterSpacing = -0.2,
        height = 1.5;

  const AppText.label(
    this.text, {
    super.key,
    this.color = AppColors.tx3,
    this.textAlign = TextAlign.start,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.softWrap = true,
  })  : poppins = false,
        noto = false,
        mono = true,
        fontSize = 10,
        fontWeight = FontWeight.w600,
        underline = false,
        underlineColor = AppColors.tx3,
        letterSpacing = 1.2,
        height = null;

  const AppText.caption(
    this.text, {
    super.key,
    this.color = AppColors.tx3,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
    this.softWrap = true,
  })  : poppins = false,
        noto = false,
        mono = false,
        fontSize = 12,
        fontWeight = FontWeight.w400,
        underline = false,
        underlineColor = AppColors.tx3,
        letterSpacing = -0.1,
        height = 1.5;

  const AppText.amber(
    this.text, {
    super.key,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w600,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
    this.softWrap = true,
    this.letterSpacing,
    this.height,
  })  : color = AppColors.amber,
        poppins = false,
        noto = false,
        mono = false,
        underline = false,
        underlineColor = AppColors.tx3;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final langCode = appLocaleLanguageCode(context);
    final isLao = langCode == 'lo';
    final display = (mono && !isLao) ? text.toUpperCase() : text;
    final style = _buildStyle(context, isLao: isLao);

    return Text(
      display,
      textAlign: textAlign,
      maxLines: maxLines,
      softWrap: softWrap,
      overflow: overflow,
      style: style,
    );
  }

  // ── Style builder ──────────────────────────────────────────────────────────

  TextStyle _buildStyle(BuildContext context, {required bool isLao}) {
    final base = TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: (mono && !isLao) ? (letterSpacing ?? 1.2) : letterSpacing,
      height: height,
      decoration: underline ? TextDecoration.underline : TextDecoration.none,
      decorationColor: underline ? underlineColor : null,
    );

    return AppFonts.resolve(
      context,
      base,
      forcePoppins: poppins && !isLao,
      forceNoto: noto || isLao,
      mono: mono,
    );
  }

  /// TextStyle ตาม locale — ใช้กับ TextField, RichText, Tooltip
  static TextStyle styleOf(
    BuildContext context, {
    Color color = AppColors.tx1,
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w400,
    double? letterSpacing,
    double? height,
    bool forcePoppins = false,
    bool mono = false,
  }) =>
      AppFonts.of(
        context,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        forcePoppins: forcePoppins,
        mono: mono,
      );

  // ── Static helpers ─────────────────────────────────────────────────────────

  /// Locale-aware font family from context. Use in raw TextStyle / RichText.
  /// Reacts to locale changes via Localizations InheritedWidget.
  static String fontFamilyOf(BuildContext context) => AppFonts.familyOf(context);

  /// Fallback when no BuildContext is available.
  static String get fontFamily {
    try {
      return LocaleController.to.current.value.languageCode == 'lo'
          ? GoogleFonts.notoSansLao().fontFamily!
          : GoogleFonts.poppins().fontFamily!;
    } catch (_) {
      return GoogleFonts.poppins().fontFamily!;
    }
  }
}
