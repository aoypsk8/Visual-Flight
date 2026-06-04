import 'dart:async';

import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart' as geo;

/// GPS + permission — returns null when denied/unavailable (caller uses fallback).
class LocationService extends GetxService {
  static LocationService get to => Get.find();

  static const _fixTimeout = Duration(seconds: 10);

  Future<geo.Position?> getCurrentPosition() async {
    try {
      final enabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return _lastKnown();
      }

      var perm = await geo.Geolocator.checkPermission();
      if (perm == geo.LocationPermission.denied) {
        perm = await geo.Geolocator.requestPermission();
      }
      if (perm == geo.LocationPermission.denied ||
          perm == geo.LocationPermission.deniedForever) {
        return _lastKnown();
      }

      // ใช้ตำแหน่งล่าสุดก่อน (เร็ว — โดยเฉพาะ simulator)
      final cached = await _lastKnown();
      if (cached != null && _isFresh(cached)) {
        unawaited(_refreshInBackground());
        return cached;
      }

      try {
        return await geo.Geolocator.getCurrentPosition(
          locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.medium,
            timeLimit: _fixTimeout,
          ),
        ).timeout(_fixTimeout);
      } catch (_) {
        return cached ?? await _lastKnown();
      }
    } catch (_) {
      return _lastKnown();
    }
  }

  Future<geo.Position?> _lastKnown() async {
    try {
      return await geo.Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  bool _isFresh(geo.Position p) {
    final age = DateTime.now().difference(p.timestamp);
    return age.inHours < 6;
  }

  Future<void> _refreshInBackground() async {
    try {
      await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.medium,
          timeLimit: _fixTimeout,
        ),
      ).timeout(_fixTimeout);
    } catch (_) {}
  }
}
