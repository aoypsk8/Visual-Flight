import '../models/live_flight_session.dart';
import 'app_local_storage.dart';

/// Persists in-progress live flight so progress survives background/reload.
class LiveFlightSessionStore {
  LiveFlightSessionStore._();

  static const _key = 'live_flight_session';

  static void save(LiveFlightSession session) {
    AppLocalStorage.writeJsonMap(_key, session.toJson());
  }

  static LiveFlightSession? read() {
    final raw = AppLocalStorage.readJsonMap(_key);
    if (raw == null) return null;
    try {
      return LiveFlightSession.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  static void clear() => AppLocalStorage.remove(_key);
}
