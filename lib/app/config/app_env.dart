import 'package:flutter_dotenv/flutter_dotenv.dart';

// Reads values from the .env file loaded at app start.
// Usage anywhere in the app: AppEnv.baseUrl
class AppEnv {
  AppEnv._();

  static String get baseUrl =>
      dotenv.get('API_BASE_URL', fallback: 'http://localhost:3000');

  static String get apiKey =>
      dotenv.get('API_KEY', fallback: '');

  static String get mapboxToken =>
      dotenv.get('MAPBOX_ACCESS_TOKEN', fallback: '');

  static bool get isProduction =>
      const bool.fromEnvironment('dart.vm.product');
}
