import 'package:get_storage/get_storage.dart';
import '../models/live_flight_session.dart';

/// Persists in-progress live flight so progress survives background/reload.
class LiveFlightSessionStore {
  LiveFlightSessionStore._();

  static const _key = 'live_flight_session';
  static final _box = GetStorage();

  static void save(LiveFlightSession session) {
    _box.write(_key, session.toJson());
  }

  static LiveFlightSession? read() {
    final raw = _box.read(_key);
    if (raw is! Map) return null;
    try {
      return LiveFlightSession.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  static void clear() => _box.remove(_key);
}
