import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart' as geo;

// Wraps Geolocator: requests permission and returns the current GPS fix.
// Returns null silently on denial or timeout — callers treat null as "use default".
class LocationService extends GetxService {
  static LocationService get to => Get.find();

  Future<geo.Position?> getCurrentPosition() async {
    try {
      if (!await geo.Geolocator.isLocationServiceEnabled()) {
        return null;
      }

      var perm = await geo.Geolocator.checkPermission();
      if (perm == geo.LocationPermission.denied) {
        perm = await geo.Geolocator.requestPermission();
      }
      if (perm == geo.LocationPermission.denied ||
          perm == geo.LocationPermission.deniedForever) {
        return null;
      }

      try {
        return await geo.Geolocator.getCurrentPosition(
          locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.medium,
            timeLimit: Duration(seconds: 12),
          ),
        ).timeout(const Duration(seconds: 12));
      } catch (_) {
        // Fall back to last known fix when GPS is not ready (e.g. simulator).
        return geo.Geolocator.getLastKnownPosition();
      }
    } catch (_) {
      return null;
    }
  }
}
