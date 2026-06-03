import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class AppTranslations extends Translations {
  static Map<String, Map<String, String>> _data = {};

  static Future<void> load() async {
    final en = await rootBundle.loadString('assets/translations/en_US.json');
    final lo = await rootBundle.loadString('assets/translations/lo_LA.json');
    _data = {
      'en_US': Map<String, String>.from(jsonDecode(en) as Map),
      'lo_LA': Map<String, String>.from(jsonDecode(lo) as Map),
    };
  }

  @override
  Map<String, Map<String, String>> get keys => _data;
}
