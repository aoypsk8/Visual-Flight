import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/locale_controller.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_locale_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppText
//
// Uses Google Fonts (internet) — no local font files needed.
// Font detection via Localizations.localeOf(context): reactive InheritedWidget
// that rebuilds this widget whenever GetMaterialApp.locale changes.
//
//   EN → GoogleFonts.poppins()
//   LO → GoogleFonts.notoSansLao()
//   mono → 'Menlo' system font (iOS/macOS) or monospace fallback
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

  static final Set<String> _loggedFontKeys = {};

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
    final style = _buildStyle(isLao: isLao, localeCode: langCode);

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

  TextStyle _buildStyle({
    required bool isLao,
    required String localeCode,
  }) {
    final base = TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: (mono && !isLao) ? (letterSpacing ?? 1.2) : letterSpacing,
      height: height,
      decoration: underline ? TextDecoration.underline : TextDecoration.none,
      decorationColor: underline ? underlineColor : null,
    );

    late final TextStyle resolved;
    late final String source;
    if (mono && !isLao) {
      source = 'mono/Menlo';
      resolved = base.copyWith(fontFamily: 'Menlo');
    } else if (poppins) {
      source = 'force/poppins';
      resolved = GoogleFonts.poppins(textStyle: base);
    } else if (noto) {
      source = 'force/notoSansLao';
      resolved = GoogleFonts.notoSansLao(textStyle: base);
    } else {
      source = isLao ? 'locale/notoSansLao' : 'locale/poppins';
      resolved = isLao
          ? GoogleFonts.notoSansLao(textStyle: base)
          : GoogleFonts.poppins(textStyle: base);
    }

    _logFontIfNeeded(
      localeCode: localeCode,
      family: resolved.fontFamily ?? 'unknown',
      source: source,
      sample: text,
    );

    return resolved;
  }

  static void _logFontIfNeeded({
    required String localeCode,
    required String family,
    required String source,
    String? sample,
  }) {
    if (!kDebugMode || !logFontResolution) return;

    final key = '$localeCode|$family|$source';
    if (!logEveryBuild && _loggedFontKeys.contains(key)) return;
    _loggedFontKeys.add(key);

    final preview = sample == null
        ? ''
        : ' text="${sample.length > 30 ? '${sample.substring(0, 30)}...' : sample}"';
    debugPrint('[AppText] locale=$localeCode font=$family source=$source$preview');
  }

  /// Clear font log cache (call after locale change to re-log)
  static void clearFontLogCache() => _loggedFontKeys.clear();

  // ── Static helpers ─────────────────────────────────────────────────────────

  /// Locale-aware font family from context. Use in raw TextStyle / RichText.
  /// Reacts to locale changes via Localizations InheritedWidget.
  static String fontFamilyOf(BuildContext context) {
    final langCode = appLocaleLanguageCode(context);
    final isLao = langCode == 'lo';
    final family = isLao
        ? GoogleFonts.notoSansLao().fontFamily!
        : GoogleFonts.poppins().fontFamily!;
    _logFontIfNeeded(
      localeCode: langCode,
      family: family,
      source: isLao ? 'static/locale-noto' : 'static/locale-poppins',
    );
    return family;
  }

  /// Fallback when no BuildContext is available.
  static String get fontFamily {
    try {
      final lang = LocaleController.to.current.value.languageCode;
      final family = lang == 'lo'
          ? GoogleFonts.notoSansLao().fontFamily!
          : GoogleFonts.poppins().fontFamily!;
      _logFontIfNeeded(
        localeCode: lang,
        family: family,
        source: 'static/controller',
      );
      return family;
    } catch (_) {
      final family = GoogleFonts.poppins().fontFamily!;
      _logFontIfNeeded(
        localeCode: 'en',
        family: family,
        source: 'static/fallback-poppins',
      );
      return family;
    }
  }
}
