// lib/features/head_manager/screens/hm_shell.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/route_constants.dart';
import '../../../shared/widgets/web_shell.dart';

class HmShell extends StatelessWidget {
  final Widget child;
  const HmShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return WebShell(
      title: _titleFor(location),
      navItems: const [
        WebNavItem(
          label: 'Dashboard',
          route: RouteConstants.hmDashboard,
          icon: AppIcons.dashboard,
          activeIcon: AppIcons.dashboard,
        ),
        WebNavItem(
          label: 'Loans',
          route: RouteConstants.hmLoans,
          icon: AppIcons.loans,
          activeIcon: AppIcons.loans,
        ),
        WebNavItem(
          label: 'KYC',
          route: RouteConstants.hmKyc,
          icon: AppIcons.kyc,
          activeIcon: AppIcons.kyc,
        ),
        WebNavItem(
          label: 'Assignments',
          route: RouteConstants.hmAssignments,
          icon: AppIcons.assignments,
          activeIcon: AppIcons.assignments,
        ),
        WebNavItem(
          label: 'Users',
          route: RouteConstants.hmUsers,
          icon: AppIcons.users,
          activeIcon: AppIcons.users,
        ),
        WebNavItem(
          label: 'Payments',
          route: RouteConstants.hmPayments,
          icon: AppIcons.payments,
          activeIcon: AppIcons.payments,
        ),
        WebNavItem(
          label: 'Analytics',
          route: RouteConstants.hmAnalytics,
          icon: AppIcons.analytics,
          activeIcon: AppIcons.analytics,
        ),
        WebNavItem(
          label: 'Reports',
          route: RouteConstants.hmReports,
          icon: AppIcons.download,
          activeIcon: AppIcons.download,
        ),
        WebNavItem(
          label: 'Audit Log',
          route: RouteConstants.hmAudit,
          icon: AppIcons.audit,
          activeIcon: AppIcons.audit,
        ),
        WebNavItem(
          label: 'Settings',
          route: RouteConstants.hmSettings,
          icon: AppIcons.settings,
          activeIcon: AppIcons.settings,
        ),
      ],
      child: child,
    );
  }

  String _titleFor(String location) {
    if (location.startsWith('/hm/loans')) return 'Loan Management';
    if (location.startsWith('/hm/payments')) return 'Payments';
    if (location.startsWith('/hm/users')) return 'User Management';
    if (location.startsWith('/hm/kyc')) return 'KYC Review';
    if (location.startsWith('/hm/assignments')) return 'Assignments';
    if (location.startsWith('/hm/analytics')) return 'Analytics';
    if (location.startsWith('/hm/reports')) return 'Reports';
    if (location.startsWith('/hm/audit')) return 'Audit Log';
    if (location.startsWith('/hm/settings')) return 'System Settings';
    if (location.startsWith('/hm/profile')) return 'My Profile';
    if (location.startsWith('/hm/notifications')) return 'Notifications';
    return 'Dashboard';
  }
}