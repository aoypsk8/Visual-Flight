import 'package:flutter/material.dart';
import '../controllers/locale_controller.dart';

/// Language code from LocaleController (source of truth) — independent of Material delegate
String appLocaleLanguageCode(BuildContext context) {
  try {
    return LocaleController.to.current.value.languageCode;
  } catch (_) {
    return Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
  }
}

bool isLaoLocale(BuildContext context) =>
    appLocaleLanguageCode(context) == 'lo';
