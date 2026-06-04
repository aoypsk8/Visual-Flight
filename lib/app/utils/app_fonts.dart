import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/locale_controller.dart';
import 'app_locale_utils.dart';

/// ฟอนต์ตาม locale — EN: Poppins, LO: Noto Sans Lao
final class AppFonts {
  AppFonts._();

  static bool _isLao(BuildContext? context) {
    if (context != null) return isLaoLocale(context);
    try {
      return LocaleController.to.current.value.languageCode == 'lo';
    } catch (_) {
      return false;
    }
  }

  /// ใส่ฟอนต์ที่ถูกต้องให้ [base] ตามภาษาปัจจุบัน
  static TextStyle resolve(
    BuildContext context,
    TextStyle base, {
    bool forcePoppins = false,
    bool forceNoto = false,
    bool mono = false,
  }) {
    final isLao = _isLao(context);
    if (mono && !isLao) {
      return base.copyWith(fontFamily: 'Menlo');
    }
    if (forceNoto || (isLao && !forcePoppins)) {
      return GoogleFonts.notoSansLao(textStyle: base);
    }
    return GoogleFonts.poppins(textStyle: base);
  }

  /// สร้าง TextStyle สำหรับ Text / TextField / RichText
  static TextStyle of(
    BuildContext context, {
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    bool forcePoppins = false,
    bool forceNoto = false,
    bool mono = false,
  }) {
    return resolve(
      context,
      TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        decoration: decoration,
        decorationColor: decorationColor,
      ),
      forcePoppins: forcePoppins,
      forceNoto: forceNoto,
      mono: mono,
    );
  }

  static String familyOf(BuildContext context) {
    final isLao = _isLao(context);
    return isLao
        ? GoogleFonts.notoSansLao().fontFamily!
        : GoogleFonts.poppins().fontFamily!;
  }
}
