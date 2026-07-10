// lib/features/employee/screens/emp_shell.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/route_constants.dart';
import '../../../shared/widgets/web_shell.dart';

class EmpShell extends ConsumerWidget {
  final Widget child;
  const EmpShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          label: 'Users',
          route: RouteConstants.empUsers,
          icon: AppIcons.users,
          activeIcon: AppIcons.users,
        ),
        WebNavItem(
          label: 'Payments',
          route: RouteConstants.empPayments,
          icon: AppIcons.payments,
          activeIcon: AppIcons.payments,
        ),
      ],
      child: _EmpShellBody(child: child),
    );
  }

  String _titleFor(String location) {
    if (location.startsWith('/emp/loans')) return 'Loan Management';
    if (location.startsWith('/emp/payments')) return 'Payments';
    if (location.startsWith('/emp/kyc')) return 'KYC Review';
    if (location.startsWith('/emp/assignments')) return 'Assignments';
    if (location.startsWith('/emp/users')) return 'User Management';
    if (location.startsWith('/emp/profile')) return 'My Profile';
    if (location.startsWith('/emp/notifications')) return 'Notifications';
    return 'Dashboard';
  }
}

class _EmpShellBody extends ConsumerWidget {
  final Widget child;
  const _EmpShellBody({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return child;
  }
}
