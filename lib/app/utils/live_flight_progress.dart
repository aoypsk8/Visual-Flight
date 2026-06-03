import '../models/live_flight_session.dart';

/// Values derived from [progress] — kept in sync across HUD, map, and scrubber.
class LiveFlightProgress {
  const LiveFlightProgress({
    required this.progress,
    required this.totalMin,
    required this.totalKm,
  });

  final double progress;
  final double totalMin;
  final double totalKm;

  factory LiveFlightProgress.fromSession(
    LiveFlightSession session,
    DateTime now,
  ) {
    return LiveFlightProgress(
      progress: session.progressAt(now),
      totalMin: session.totalSeconds / 60.0,
      totalKm: session.totalKm,
    );
  }

  double get elapsedMin => progress * totalMin;
  double get remainingMin => (1 - progress) * totalMin;
  int get distanceLeftKm => ((1 - progress) * totalKm).round();
  int get percent => (progress * 100).round();

  /// `mm:ss` from fractional minutes.
  static String formatMinutes(double minutes) {
    final totalSec = (minutes * 60).round();
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get remainingLabel => formatMinutes(remainingMin);
  String get elapsedLabel => formatMinutes(elapsedMin);
  String get totalLabel => formatMinutes(totalMin);
  String get distanceLeftLabel => '$distanceLeftKm km';
  String get percentLabel => '$percent%';

  String? get altitudeFlavor {
    if (progress < 0.18) return 'climbing · +1800 ft/m';
    if (progress > 0.82) return 'descending · -1500 ft/m';
    return 'FL310 · 412 km/h';
  }
}
