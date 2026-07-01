// lib/features/rider/screens/rider_shell.dart

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
          label: 'Assignments',
          route: RouteConstants.riderAssignments,
          icon: AppIcons.assignments,
          activeIcon: AppIcons.assignments,
        ),
        MobileNavItem(
          label: 'History',
          route: RouteConstants.riderHistory,
          icon: AppIcons.history,
          activeIcon: AppIcons.history,
        ),
        MobileNavItem(
          label: 'Profile',
          route: RouteConstants.riderProfile,
          icon: AppIcons.profile,
          activeIcon: AppIcons.profile,
        ),
      ],
      child: child,
    );
  }
}