// lib/features/lender/screens/lender_shell.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/mobile_shell.dart';

class LenderShell extends StatelessWidget {
  final Widget child;
  const LenderShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MobileShell(
      gradientColors: const [
        AppColors.lenderGradientStart,
        AppColors.lenderGradientMid,
        AppColors.lenderGradientEnd,
      ],
      accentColor: AppColors.lenderAccent,
      navItems: const [
        MobileNavItem(
          label: 'Home',
          route: RouteConstants.lenderHome,
          icon: AppIcons.home,
          activeIcon: AppIcons.home,
        ),
        MobileNavItem(
          label: 'My Loans',
          route: RouteConstants.lenderLoans,
          icon: AppIcons.loans,
          activeIcon: AppIcons.loans,
        ),
        MobileNavItem(
          label: 'Alerts',
          route: RouteConstants.lenderAlerts,
          icon: AppIcons.notifications,
          activeIcon: AppIcons.notifications,
        ),
        MobileNavItem(
          label: 'Profile',
          route: RouteConstants.lenderProfile,
          icon: AppIcons.profile,
          activeIcon: AppIcons.profile,
        ),
      ],
      child: child,
    );
  }
}