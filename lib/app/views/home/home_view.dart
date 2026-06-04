import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/home_controller.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common/locale_reactive.dart';
import '../../widgets/navigation/app_bottom_nav.dart';
import 'home_tabs.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  /// Flight + Car share one search map (avoids duplicate Mapbox native views).
  static const _pages = <Widget>[
    SearchTabPage(key: ValueKey('search-tab')),
    ProfileTabPage(key: ValueKey('profile-tab')),
  ];

  static int _pageIndexForTab(int tab) => tab >= 2 ? 1 : 0;

  @override
  Widget build(BuildContext context) {
    final ctrl = HomeController.to;

    return LocaleReactive(
      builder: (context) => Scaffold(
      backgroundColor: context.colors.surf1,
      body: Stack(
        children: [
          // Tab content — directional slide transition
          Obx(
            () => _SlideTabView(
              currentIndex: _pageIndexForTab(ctrl.currentTab.value),
              pages: _pages,
            ),
          ),

          // Floating pill nav — overlaid at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Obx(
              () => AppBottomNav(
                currentIndex: ctrl.currentTab.value,
                onTap: ctrl.setTab,
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Directional slide switcher
//
// • Going to a higher-index tab → incoming slides in from the right
// • Going to a lower-index tab  → incoming slides in from the left
// • Outgoing page fades + drifts at 25 % speed (parallax depth)
// ─────────────────────────────────────────────────────────────────────────────

class _SlideTabView extends StatefulWidget {
  final int currentIndex;
  final List<Widget> pages;

  const _SlideTabView({
    required this.currentIndex,
    required this.pages,
  });

  @override
  State<_SlideTabView> createState() => _SlideTabViewState();
}

class _SlideTabViewState extends State<_SlideTabView> {
  int _prevIndex = 0;

  @override
  void didUpdateWidget(covariant _SlideTabView old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _prevIndex = old.currentIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final forward = widget.currentIndex >= _prevIndex;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        children: [
          ...previous,
          ?current,
        ],
      ),
      transitionBuilder: (child, animation) {
        final isIncoming =
            (child.key as ValueKey<int>).value == widget.currentIndex;

        if (isIncoming) {
          // New page slides fully in from the correct side
          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset(forward ? 1.0 : -1.0, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        } else {
          // Old page fades + drifts out at 25 % speed (parallax)
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(forward ? -0.25 : 0.25, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        }
      },
      child: KeyedSubtree(
        key: ValueKey(widget.currentIndex),
        child: widget.pages[widget.currentIndex],
      ),
    );
  }
}
