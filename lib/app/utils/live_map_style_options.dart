import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Map style choices for Live Flight (English + Lao labels only).
class LiveMapStyleOption {
  const LiveMapStyleOption({
    required this.id,
    required this.label,
    required this.subtitleEn,
    required this.subtitleLo,
    required this.styleUri,
    required this.icon,
    required this.previewTop,
    required this.previewBottom,
    required this.accent,
    this.supportsStandard3dConfig = false,
  });

  final String id;
  final String label;
  final String subtitleEn;
  final String subtitleLo;
  final String styleUri;
  final IconData icon;
  final Color previewTop;
  final Color previewBottom;
  final Color accent;

  /// Mapbox Standard basemap: show3dBuildings / show3dObjects
  final bool supportsStandard3dConfig;
}

/// Two map styles only: Normal 3D and Satellite 3D.
abstract final class LiveMapStyleOptions {
  static const String defaultId = 'normal_3d';

  static const List<LiveMapStyleOption> all = [
    LiveMapStyleOption(
      id: 'normal_3d',
      label: 'Normal 3D',
      subtitleEn: 'Streets · 3D buildings',
      subtitleLo: 'ຖນົນ · ຕຶກ 3D',
      styleUri: MapboxStyles.STANDARD,
      icon: Icons.view_in_ar_rounded,
      previewTop: Color(0xFF5B7FA8),
      previewBottom: Color(0xFF1E2A3A),
      accent: Color(0xFFF6A93B),
      supportsStandard3dConfig: true,
    ),
    LiveMapStyleOption(
      id: 'satellite_3d',
      label: 'Satellite 3D',
      subtitleEn: 'Satellite · terrain',
      subtitleLo: 'ດາວທຽມ · ພູມສັນທະເທດ',
      styleUri: MapboxStyles.STANDARD_SATELLITE,
      icon: Icons.satellite_alt_rounded,
      previewTop: Color(0xFF1B4D3E),
      previewBottom: Color(0xFF0A1628),
      accent: Color(0xFF6EC9E8),
      supportsStandard3dConfig: false,
    ),
  ];

  static LiveMapStyleOption byId(String id) {
    return all.firstWhere(
      (o) => o.id == id,
      orElse: () => all.first,
    );
  }
}
