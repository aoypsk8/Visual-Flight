/// Local asset paths for flight sounds (see assets/sounds/README.md).
abstract final class FlightAudioAssets {
  static const String folder = 'assets/sounds';

  /// Single audio track used throughout the flight (looped from this point)
  static const String cruise = '$folder/flight_cruise.mp3';

  /// Loop start point at 0:08 in flight_cruise.mp3
  static const Duration cruiseLoopStart = Duration(seconds: 8);

  static const double liveVolume = 1.0;
}
