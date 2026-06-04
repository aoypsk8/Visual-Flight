import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/app_colors.dart';
import '../../utils/live_map_style_options.dart';

/// Shared map UI chrome for live flight & road trip maps.
class LiveMapLoadingOverlay extends StatelessWidget {
  const LiveMapLoadingOverlay({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0C0D10).withValues(alpha: 0.55),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.amber,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LiveMapTripStatusBar extends StatelessWidget {
  const LiveMapTripStatusBar({
    super.key,
    required this.fromLabel,
    required this.toLabel,
    required this.percent,
    required this.isFollowing,
    required this.mapStyleLabel,
    required this.map3dEnabled,
    required this.showBuildingHint,
    required this.followZoom,
    required this.buildingVisibleZoom,
    required this.trackingTitle,
    required this.exploreTitle,
  });

  final String fromLabel;
  final String toLabel;
  final int percent;
  final bool isFollowing;
  final String mapStyleLabel;
  final bool map3dEnabled;
  final bool showBuildingHint;
  final double followZoom;
  final double buildingVisibleZoom;
  final String trackingTitle;
  final String exploreTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF16181D).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFollowing
              ? AppColors.amber.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isFollowing ? Icons.radar_rounded : Icons.gps_not_fixed_rounded,
            size: 18,
            color: isFollowing ? AppColors.amber : Colors.white54,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFollowing ? trackingTitle : exploreTitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  mapStyleLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (showBuildingHint && followZoom < buildingVisibleZoom)
                  Text(
                    'Pinch zoom in (≥${buildingVisibleZoom.toStringAsFixed(0)}) to see 3D buildings',
                    style: TextStyle(
                      color: AppColors.amber.withValues(alpha: 0.85),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  '$fromLabel → $toLabel · $percent% along route',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isFollowing
                  ? AppColors.amber.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$percent%',
              style: TextStyle(
                color: isFollowing ? AppColors.amber : Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LiveMapViewControls extends StatelessWidget {
  const LiveMapViewControls({
    super.key,
    required this.isFollowing,
    required this.map3dEnabled,
    required this.onPickStyle,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onExplore,
    required this.onRouteOverview,
    required this.onToggle3d,
    required this.onFollow,
    this.followTooltip = 'Follow',
    this.exploreTooltip = 'Explore map',
  });

  final bool isFollowing;
  final bool map3dEnabled;
  final VoidCallback onPickStyle;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onExplore;
  final VoidCallback onRouteOverview;
  final VoidCallback onToggle3d;
  final VoidCallback onFollow;
  final String followTooltip;
  final String exploreTooltip;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LiveMapZoomButton(
          icon: isFollowing
              ? Icons.explore_outlined
              : Icons.my_location_rounded,
          onTap: isFollowing ? onExplore : onFollow,
          amber: true,
          tooltip: isFollowing ? exploreTooltip : followTooltip,
        ),
        const SizedBox(height: 8),
        LiveMapZoomButton(
          icon: Icons.public_rounded,
          onTap: onRouteOverview,
          tooltip: 'Route overview',
        ),
        const SizedBox(height: 8),
        LiveMapZoomButton(
          icon: Icons.layers_rounded,
          onTap: onPickStyle,
          tooltip: 'Map style',
        ),
        const SizedBox(height: 8),
        LiveMapZoomButton(
          icon: map3dEnabled ? Icons.view_in_ar_rounded : Icons.map_rounded,
          onTap: onToggle3d,
          amber: map3dEnabled,
          tooltip: map3dEnabled ? 'Switch to 2D map' : 'Switch to 3D map',
        ),
        const SizedBox(height: 8),
        LiveMapZoomButton(icon: Icons.add_rounded, onTap: onZoomIn),
        const SizedBox(height: 8),
        LiveMapZoomButton(icon: Icons.remove_rounded, onTap: onZoomOut),
      ],
    );
  }
}

class LiveMapZoomButton extends StatelessWidget {
  const LiveMapZoomButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.amber = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool amber;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: amber
                ? AppColors.amber.withValues(alpha: 0.75)
                : Colors.white.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10),
          ],
        ),
        child: Icon(
          icon,
          size: 22,
          color: amber ? AppColors.amber : Colors.white.withValues(alpha: 0.88),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

void showLiveMapStylePicker(
  BuildContext context, {
  required String selectedId,
  required String subtitle,
  required ValueChanged<LiveMapStyleOption> onSelected,
}) {
  HapticFeedback.selectionClick();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.46,
      minChildSize: 0.38,
      maxChildSize: 0.58,
      expand: false,
      builder: (_, scrollController) => LiveMapStylePickerSheet(
        scrollController: scrollController,
        selectedId: selectedId,
        subtitle: subtitle,
        onSelected: (option) {
          Navigator.pop(ctx);
          onSelected(option);
        },
      ),
    ),
  );
}

class LiveMapStylePickerSheet extends StatelessWidget {
  const LiveMapStylePickerSheet({
    super.key,
    required this.scrollController,
    required this.selectedId,
    required this.subtitle,
    required this.onSelected,
  });

  final ScrollController scrollController;
  final String selectedId;
  final String subtitle;
  final ValueChanged<LiveMapStyleOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF222833).withValues(alpha: 0.96),
                const Color(0xFF0E1016).withValues(alpha: 0.98),
              ],
            ),
            border: Border(
              top: BorderSide(color: AppColors.amber.withValues(alpha: 0.25)),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + bottom),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Map style',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.96),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.48),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < LiveMapStyleOptions.all.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: _StyleCard(
                        option: LiveMapStyleOptions.all[i],
                        selected: LiveMapStyleOptions.all[i].id == selectedId,
                        onTap: () => onSelected(LiveMapStyleOptions.all[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final LiveMapStyleOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? option.accent : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 72,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                gradient: LinearGradient(
                  colors: [option.previewTop, option.previewBottom],
                ),
              ),
              child: Icon(option.icon, color: Colors.white70, size: 32),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                option.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centered vehicle marker while the camera follows.
class LiveMapVehicleOverlay extends StatelessWidget {
  const LiveMapVehicleOverlay({
    super.key,
    required this.pulse,
    required this.icon,
  });

  final double pulse;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _PulseRing(radius: 28 + pulse * 20, opacity: (1 - pulse) * 0.5),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.amber,
              boxShadow: [
                BoxShadow(
                  color: AppColors.amber.withValues(alpha: 0.45),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF0A0B0D), size: 28),
          ),
        ],
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({required this.radius, required this.opacity});

  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.amber.withValues(alpha: opacity),
          width: 2,
        ),
      ),
    );
  }
}
