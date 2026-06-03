import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_theme.dart';
import '../common/app_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppBottomNav — floating pill nav with sliding amber highlight
// ─────────────────────────────────────────────────────────────────────────────

class AppBottomNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int? badge;

  const AppBottomNavItem({
    required this.icon,
    required this.label,
    IconData? activeIcon,
    this.badge,
  }) : activeIcon = activeIcon ?? icon;
}

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppBottomNavItem> items;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.items = kAppBottomNavItems,
  });

  static const List<AppBottomNavItem> kAppBottomNavItems = [
    AppBottomNavItem(
      icon: Icons.travel_explore_outlined,
      activeIcon: Icons.travel_explore_rounded,
      label: 'Search',
    ),
    AppBottomNavItem(
      icon: Icons.near_me_outlined,
      activeIcon: Icons.near_me_rounded,
      label: 'Explore',
    ),
    AppBottomNavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  static const double _navHeight   = 62;
  static const double _pillHeight  = 52;
  static const double _pillPadding = 8; // horizontal inset per side
  static const double _bottomMargin = 12;

  /// Space to reserve above the floating bottom nav (nav + safe area + margins).
  static double overlayClearance(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return _navHeight + bottomInset + _bottomMargin + 16;
  }

  @override
  Widget build(BuildContext context) {
    final colors      = context.colors;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + _bottomMargin),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final navWidth  = constraints.maxWidth;
          final itemWidth = navWidth / items.length;
          final pillWidth = itemWidth - _pillPadding * 2;
          final pillLeft  = currentIndex * itemWidth + _pillPadding;
          final pillTop   = (_navHeight - _pillHeight) / 2;

          return Container(
            height: _navHeight,
            decoration: BoxDecoration(
              color: colors.surf2,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.hair2, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                      alpha: colors.isDark ? 0.40 : 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // ── Sliding amber pill ─────────────────────────────────────
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  left: pillLeft,
                  top: pillTop,
                  width: pillWidth,
                  height: _pillHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(20, 246, 168, 59),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),

                // ── Tab tiles ──────────────────────────────────────────────
                Row(
                  children: List.generate(items.length, (i) => _NavTile(
                    item: items[i],
                    isActive: currentIndex == i,
                    onTap: () => onTap(i),
                  )),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  final AppBottomNavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon + optional badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Icon(
                    isActive ? item.activeIcon : item.icon,
                    key: ValueKey(isActive),
                    size: 22,
                    color: isActive ? AppColors.amber : colors.tx3,
                  ),
                ),
                if (item.badge != null && item.badge! > 0)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.amber,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: AppText(
                        '${item.badge}',
                        color: const Color(0xFF0A0B0D),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0.2,
                color: isActive ? AppColors.amber : colors.tx3,
              ),
              child: AppText(
                item.label,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0.2,
                poppins: true,
                color: isActive ? AppColors.amber : colors.tx3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
