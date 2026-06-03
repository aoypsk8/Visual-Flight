import 'package:flutter/material.dart';

final class AppAssets {
  AppAssets._();

  static const String icons = 'assets/icons';
  static const String images = 'assets/images';
  static const String animations = 'assets/animations';
  static const String lottie = 'assets/lottie';
  static const String translations = 'assets/translations';
  static const String ui = 'assets/UI';
}

/// Live flight & landing reference photography.
final class AppUiAssets {
  AppUiAssets._();

  static const String liveWindow = '${AppAssets.ui}/live.jpg';
  static const String liveTail = '${AppAssets.ui}/live.jpg';
  static const String finishedFlight = '${AppAssets.ui}/finishedFlight.jpg';
}

/// Seat selection screen — airplane background (PNG in [AppAssets.images]).
const kSeatAirplaneBgAsset = '${AppAssets.images}/seat_airplane_bg.png';

final class AppLottie {
  AppLottie._();

  static const String location = '${AppAssets.lottie}/location.json';
  static const String camera = '${AppAssets.lottie}/camera.json';
  static const String gallery = '${AppAssets.lottie}/gallery.json';
}

final class AppAnimations {
  AppAnimations._();

  static const String businessmanRocket =
      '${AppAssets.animations}/businessman_rocket.json';
}

final class AppImages {
  AppImages._();

  static const String seatAirplaneBg = kSeatAirplaneBgAsset;
}

/// SVG icons in assets/icons + Material glyphs for UI without asset files yet
final class AppIcons {
  AppIcons._();

  // ── Social brand (SVG) ─────────────────────────────────────────────────────
  static const String google = '${AppAssets.icons}/google.svg';
  static const String apple = '${AppAssets.icons}/apple.svg';
  static const String github = '${AppAssets.icons}/github.svg';

  // ── Material glyphs (fallback until asset files are available) ───────────────────────────
  static const IconData lottieFallback = Icons.flight_takeoff_rounded;
  static const IconData chipCalmMind = Icons.self_improvement_rounded;
  static const IconData chipAutoSync = Icons.wifi_protected_setup_rounded;
  static const IconData routeCard = Icons.route_rounded;
  static const IconData seatCard = Icons.airline_seat_recline_extra_rounded;
  static const IconData status = Icons.auto_awesome;
}
