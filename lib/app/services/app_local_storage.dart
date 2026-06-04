import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local key-value storage (replaces get_storage — avoids objective_c on iOS sim).
class AppLocalStorage {
  AppLocalStorage._();

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get _p {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('Call AppLocalStorage.init() before use');
    }
    return prefs;
  }

  static bool? readBool(String key) => _p.getBool(key);

  static String? readString(String key) => _p.getString(key);

  static Map<String, dynamic>? readJsonMap(String key) {
    final raw = _p.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  static void writeBool(String key, bool value) {
    unawaited(_p.setBool(key, value));
  }

  static void writeString(String key, String value) {
    unawaited(_p.setString(key, value));
  }

  static void writeJsonMap(String key, Map<String, dynamic> value) {
    unawaited(_p.setString(key, jsonEncode(value)));
  }

  static void remove(String key) {
    unawaited(_p.remove(key));
  }
}
