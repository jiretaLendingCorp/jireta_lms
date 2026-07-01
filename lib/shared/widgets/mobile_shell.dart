// lib/shared/widgets/mobile_shell.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MobileShell extends ConsumerWidget {
  final Widget child;
  final List<MobileNavItem> navItems;
  final List<Color> gradientColors;
  final Color accentColor;

  const MobileShell({
    super.key,
    required this.child,
    required this.navItems,
    required this.gradientColors,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _indexFor(location);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        extendBody: true,
        backgroundColor: gradientColors.first,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
          ),
          // extendBody:true pushes body behind the glass nav bar.
          // Removing bottom media-query padding here and letting each
          // screen add its own bottom clearance (via padding/SizedBox)
          // prevents SafeArea inside screens from double-counting it.
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: child,
          ),
        ),
        bottomNavigationBar: _GlassNavBar(
          navItems: navItems,
          selectedIndex: selectedIndex,
          accentColor: accentColor,
          onTap: (i) => context.go(navItems[i].route),
        ),
      ),
    );
  }

  int _indexFor(String location) {
    for (var i = navItems.length - 1; i >= 0; i--) {
      if (navItems[i].route != '/' &&
          location.startsWith(navItems[i].route)) {
        return i;
      }
      if (navItems[i].route == location) return i;
    }
    return 0;
  }
}

class _GlassNavBar extends StatelessWidget {
  final List<MobileNavItem> navItems;
  final int selectedIndex;
  final Color accentColor;
  final ValueChanged<int> onTap;

  const _GlassNavBar({
    required this.navItems,
    required this.selectedIndex,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 58,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(navItems.length, (i) {
                  return _NavButton(
                    item: navItems[i],
                    isActive: i == selectedIndex,
                    accentColor: accentColor,
                    onTap: () => onTap(i),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final MobileNavItem item;
  final bool isActive;
  final Color accentColor;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.isActive,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  isActive ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4) : EdgeInsets.zero,
              decoration: BoxDecoration(
                color: isActive
                    ? accentColor.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isActive ? item.activeIcon : item.icon,
                size: 22,
                color: isActive
                    ? accentColor
                    : Colors.white.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? accentColor
                    : Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MobileNavItem {
  final String label;
  final String route;
  final IconData icon;
  final IconData activeIcon;

  const MobileNavItem({
    required this.label,
    required this.route,
    required this.icon,
    required this.activeIcon,
  });
}