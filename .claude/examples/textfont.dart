// ignore_for_file: prefer_const_constructors_in_immutables

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mmerchant_x/utils/styles/colors.dart';
import 'package:sizer/sizer.dart';

class TextFont extends StatelessWidget {
  final String text;
  final bool noto;
  final bool poppin;
  final TextAlign textAlign;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final int maxLines;
  final bool underline;
  final Color underlineColor;
  final bool args;
  final Map<String, String>? arguments;

  TextFont({
    super.key,
    required this.text,
    this.noto = false,
    this.poppin = false,
    this.textAlign = TextAlign.start,
    this.color = color_2929,
    this.fontSize = 16,
    this.fontWeight = FontWeight.normal,
    this.maxLines = 1,
    this.underline = false,
    this.underlineColor = cr_7070,
    this.args = false,
    this.arguments,
  });

  @override
  Widget build(BuildContext context) {
    String languageCode = Get.locale?.languageCode ?? 'lo';

    TextStyle textStyle;

    // Determine the appropriate font style
    if (poppin) {
      textStyle = GoogleFonts.poppins(
        fontSize: fontSize.sp,
        fontWeight: fontWeight,
        decoration: underline ? TextDecoration.underline : null,
        decorationColor: underline ? underlineColor : null,
        decorationStyle: underline ? TextDecorationStyle.solid : null,
      );
    } else if (noto) {
      textStyle = GoogleFonts.notoSansLao(
        fontSize: fontSize.sp,
        fontWeight: fontWeight,
        decoration: underline ? TextDecoration.underline : null,
        decorationColor: underline ? underlineColor : null,
        decorationStyle: TextDecorationStyle.solid,
      );
    } else {
      textStyle = _getLanguageSpecificFont(languageCode);
    }

    // Apply theme-based color for better visibility
    Color effectiveColor =
        Theme.of(context).brightness == Brightness.dark ? Colors.white : color;

    // Render the text with translation and optional arguments
    String translatedText = args ? text.trParams(arguments ?? {}) : text.tr;

    return Text(
      translatedText,
      textAlign: textAlign,
      style: textStyle.copyWith(color: effectiveColor),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  TextStyle _getLanguageSpecificFont(String languageCode) {
    switch (languageCode) {
      case 'lo':
        return GoogleFonts.notoSansLao(
          fontSize: fontSize.sp,
          fontWeight: fontWeight,
          decoration: underline ? TextDecoration.underline : null,
          decorationColor: underline ? underlineColor : null,
          decorationStyle: TextDecorationStyle.solid,
        );
      default:
        return GoogleFonts.poppins(
          fontSize: fontSize.sp,
          fontWeight: fontWeight,
          decoration: underline ? TextDecoration.underline : null,
          decorationColor: underline ? underlineColor : null,
          decorationStyle: TextDecorationStyle.solid,
        );
    }
  }
}
