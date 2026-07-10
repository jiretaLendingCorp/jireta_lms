// lib/features/rider/screens/rider_shell.dart
//
// FIX #4 + #5:
//  - Removed "CI" from bottom nav bar (was causing confusion/unneeded nav item).
//  - Bottom nav is now: Home | Collection | History | Profile
//  - "Settings" renamed to "Profile" in nav label while keeping the same
//    /rider/settings route (the settings screen doubles as the rider profile).

import 'package:flutter/material.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/mobile_shell.dart';

class RiderShell extends StatelessWidget {
  final Widget child;
  const RiderShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MobileShell(
      gradientColors: const [
        AppColors.riderGradientStart,
        AppColors.riderGradientMid,
        AppColors.riderGradientEnd,
      ],
      accentColor: AppColors.riderAccent,
      navItems: const [
        MobileNavItem(
          label: 'Home',
          route: RouteConstants.riderHome,
          icon: AppIcons.home,
          activeIcon: AppIcons.home,
        ),
        MobileNavItem(
          label: 'Collection',
          route: RouteConstants.riderAssignments,
          icon: AppIcons.assignments,
          activeIcon: AppIcons.assignments,
        ),
        // FIX: CI removed — was the 3rd item causing confusion.
        MobileNavItem(
          label: 'History',
          route: RouteConstants.riderHistory,
          icon: AppIcons.history,
          activeIcon: AppIcons.history,
        ),
        // FIX: Renamed "Settings" label to "Profile" in the bottom nav.
        // The /rider/settings route is the combined profile+settings page.
        MobileNavItem(
          label: 'Profile',
          route: RouteConstants.riderSettings,
          icon: AppIcons.profile,
          activeIcon: AppIcons.profile,
        ),
      ],
      child: child,
    );
  }
}