import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../services/app_local_storage.dart';

class ThemeController extends GetxController {
  static ThemeController get to => Get.find();

  static const _key = 'is_dark';
  late final isDark = (AppLocalStorage.readBool(_key) ?? true).obs;

  ThemeMode get themeMode =>
      isDark.value ? ThemeMode.dark : ThemeMode.light;

  @override
  void onInit() {
    super.onInit();
    _applySystemChrome(isDark.value);
  }

  void toggle() {
    isDark.value = !isDark.value;
    AppLocalStorage.writeBool(_key, isDark.value);
    Get.changeThemeMode(themeMode);
    _applySystemChrome(isDark.value);
  }

  static void _applySystemChrome(bool dark) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor:
          dark ? const Color(0xFF0C0D10) : const Color(0xFFF2F2F7),
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
    ));
  }
}
