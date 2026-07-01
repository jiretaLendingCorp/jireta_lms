// lib/features/employee/screens/emp_shell.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/route_constants.dart';
import '../../../shared/widgets/web_shell.dart';

class EmpShell extends StatelessWidget {
  final Widget child;
  const EmpShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return WebShell(
      title: _titleFor(location),
      navItems: const [
        WebNavItem(
          label: 'Dashboard',
          route: RouteConstants.empDashboard,
          icon: AppIcons.dashboard,
          activeIcon: AppIcons.dashboard,
        ),
        WebNavItem(
          label: 'Loans',
          route: RouteConstants.empLoans,
          icon: AppIcons.loans,
          activeIcon: AppIcons.loans,
        ),
        WebNavItem(
          label: 'Payments',
          route: RouteConstants.empPayments,
          icon: AppIcons.payments,
          activeIcon: AppIcons.payments,
        ),
        WebNavItem(
          label: 'KYC',
          route: RouteConstants.empKyc,
          icon: AppIcons.kyc,
          activeIcon: AppIcons.kyc,
        ),
        WebNavItem(
          label: 'Assignments',
          route: RouteConstants.empAssignments,
          icon: AppIcons.assignments,
          activeIcon: AppIcons.assignments,
        ),
        WebNavItem(
          label: 'Profile',
          route: RouteConstants.empProfile,
          icon: AppIcons.profile,
          activeIcon: AppIcons.profile,
        ),

      ],
      child: child,
    );
  }

  String _titleFor(String location) {
    if (location.startsWith('/emp/loans')) return 'Loan Management';
    if (location.startsWith('/emp/payments')) return 'Payments';
    if (location.startsWith('/emp/kyc')) return 'KYC Review';
    if (location.startsWith('/emp/assignments')) return 'Assignments';
    if (location.startsWith('/emp/profile')) return 'My Profile';
    if (location.startsWith('/emp/notifications')) return 'Notifications';
    return 'Dashboard';
  }
}