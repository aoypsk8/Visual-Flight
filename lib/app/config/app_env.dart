import 'package:flutter_dotenv/flutter_dotenv.dart';

// Reads secrets / env from `.env` loaded at app start.
// HTTP hosts & paths: see api_urls.dart ([ApiHosts], [AuthPaths], [MapboxApiPaths])
class AppEnv {
  AppEnv._();

  /// FocusFlight backend (auth, etc.) — used by [ApiClient]
  static String get baseUrl =>
      dotenv.get('API_BASE_URL', fallback: 'http://localhost:3000');

  static String get apiKey =>
      dotenv.get('API_KEY', fallback: '');

  /// Mapbox Maps SDK access token
  static String get mapboxToken =>
      dotenv.get('MAPBOX_ACCESS_TOKEN', fallback: '');

  static bool get isProduction =>
      const bool.fromEnvironment('dart.vm.product');
}
