import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class LocaleController extends GetxController {
  static LocaleController get to => Get.find();

  static const _storageKey = 'locale';

  final _box = GetStorage();

  // Supported locales
  static const List<AppLocale> supported = [
    AppLocale(code: 'en', country: 'US', label: 'EN', nativeLabel: 'English'),
    AppLocale(code: 'lo', country: 'LA', label: 'ລາວ', nativeLabel: 'ລາວ'),
  ];

  late final Rx<Locale> current;

  @override
  void onInit() {
    super.onInit();
    final saved = _box.read<String>(_storageKey);
    final initial = _localeFrom(saved) ?? Get.deviceLocale ?? const Locale('en', 'US');
    current = _clamp(initial).obs;
    Get.updateLocale(current.value);
  }

  /// Switch to a locale by language code ('en' or 'lo').
  void changeLocale(String langCode) {
    final found = supported.firstWhereOrNull((l) => l.code == langCode);
    if (found == null) return;

    final locale = Locale(found.code, found.country);
    if (current.value == locale) return;

    current.value = locale;
    _box.write(_storageKey, '${found.code}_${found.country}');
    Get.updateLocale(locale);
    Get.forceAppUpdate();
  }

  /// Toggle between the two supported locales.
  void toggle() {
    final isEn = current.value.languageCode == 'en';
    changeLocale(isEn ? 'lo' : 'en');
  }

  bool get isLao => current.value.languageCode == 'lo';
  bool get isEnglish => current.value.languageCode == 'en';

  // ── Helpers ────────────────────────────────────────────────────────────────

  Locale _clamp(Locale locale) {
    final match = supported.firstWhereOrNull((l) => l.code == locale.languageCode);
    if (match != null) return Locale(match.code, match.country);
    return const Locale('en', 'US');
  }

  Locale? _localeFrom(String? stored) {
    if (stored == null) return null;
    final parts = stored.split('_');
    if (parts.length < 2) return null;
    return Locale(parts[0], parts[1]);
  }
}

class AppLocale {
  final String code;
  final String country;
  final String label;
  final String nativeLabel;

  const AppLocale({
    required this.code,
    required this.country,
    required this.label,
    required this.nativeLabel,
  });
}
