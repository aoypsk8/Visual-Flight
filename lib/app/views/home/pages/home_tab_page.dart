import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../utils/app_theme.dart';

class HomeTabPage extends StatefulWidget {
  const HomeTabPage({super.key});

  @override
  State<HomeTabPage> createState() => _HomeTabPageState();
}

class _HomeTabPageState extends State<HomeTabPage> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Stack(
      children: [
        // ── Full-screen globe, follows device location ─────────────────────
        MapWidget(
          styleUri: 'mapbox://styles/mapbox/satellite-streets-v12',
          viewport: const FollowPuckViewportState(
            zoom: 4.5,
            pitch: 30.0,
            bearing: FollowPuckViewportStateBearingConstant(0),
          ),
          onMapCreated: _onMapCreated,
        ),

        _MapEdgeScrim(colors: colors, top: true, height: 220),
        _MapEdgeScrim(colors: colors, top: false, height: 300),
      ],
    );
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    // Globe projection — full spherical Earth
    await map.style.setProjection(
      StyleProjection(name: StyleProjectionName.globe),
    );

    // Atmosphere glow around the globe edge
    await map.style.addLayer(SkyLayer(
      id: 'sky',
      skyType: SkyType.ATMOSPHERE,
      skyAtmosphereSun: [0.0, 90.0],
      skyAtmosphereSunIntensity: 15.0,
    ));

    // 3D-style location puck with amber pulse ring
    await map.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      pulsingColor: 0xFFF6A93B, // amber
      locationPuck: LocationPuck(
        locationPuck2D: DefaultLocationPuck2D(),
      ),
    ));
  }
}

// Map edge vignette — light mode uses a darker scrim than surf1.

class _MapEdgeScrim extends StatelessWidget {
  final AppTheme colors;
  final bool top;
  final double height;

  const _MapEdgeScrim({
    required this.colors,
    required this.top,
    required this.height,
  });

  static const _lightScrim = Color(0xFF0A0B0D);

  BoxDecoration _decoration() {
    if (colors.isDark) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: top ? Alignment.topCenter : Alignment.bottomCenter,
          end: top ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [
            colors.surf1,
            colors.surf1.withValues(alpha: 0.0),
          ],
        ),
      );
    }

    // Light mode — stronger vignette for contrast on the satellite map.
    return BoxDecoration(
      gradient: LinearGradient(
        begin: top ? Alignment.topCenter : Alignment.bottomCenter,
        end: top ? Alignment.bottomCenter : Alignment.topCenter,
        colors: [
          _lightScrim.withValues(alpha: 0.88),
          _lightScrim.withValues(alpha: 0.42),
          _lightScrim.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: 0,
      right: 0,
      height: height,
      child: IgnorePointer(child: DecoratedBox(decoration: _decoration())),
    );
  }
}
