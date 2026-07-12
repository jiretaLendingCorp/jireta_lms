// lib/core/router/app_router.dart
// Fixed: splash only shows on first app launch, not after sign-in.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/route_constants.dart';
import '../providers/auth_provider.dart';
import '../../shared/models/app_user.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/force_change_password_screen.dart';
import '../../features/auth/screens/terms_screen.dart';
import '../../features/head_manager/screens/hm_shell.dart';
import '../../features/head_manager/screens/dashboard/hm_dashboard_screen.dart';
import '../../features/head_manager/screens/loans/hm_loans_screen.dart';
import '../../features/head_manager/screens/loans/hm_loan_detail_screen.dart';
import '../../features/head_manager/screens/payments/hm_payments_screen.dart';
import '../../features/head_manager/screens/users/hm_users_screen.dart';
import '../../features/head_manager/screens/users/hm_user_detail_screen.dart';
import '../../features/head_manager/screens/kyc/hm_kyc_screen.dart';
import '../../features/head_manager/screens/assignments/hm_assignments_screen.dart';
import '../../features/head_manager/screens/analytics/hm_analytics_screen.dart';
import '../../features/head_manager/screens/audit/hm_audit_screen.dart';
import '../../features/head_manager/screens/settings/hm_settings_screen.dart';
import '../../features/head_manager/screens/profile/hm_profile_screen.dart';
import '../../features/head_manager/screens/notifications/hm_notifications_screen.dart';
import '../../features/head_manager/screens/reports/hm_reports_screen.dart';
import '../../features/employee/screens/emp_shell.dart';
import '../../features/employee/screens/dashboard/emp_dashboard_screen.dart';
import '../../features/employee/screens/loans/emp_loans_screen.dart';
import '../../features/employee/screens/loans/emp_loan_detail_screen.dart';
import '../../features/employee/screens/payments/emp_payments_screen.dart';
import '../../features/employee/screens/kyc/emp_kyc_screen.dart';
import '../../features/employee/screens/assignments/emp_assignments_screen.dart';
import '../../features/employee/screens/users/emp_users_screen.dart';
import '../../features/employee/screens/profile/emp_profile_screen.dart';
import '../../features/employee/screens/notifications/emp_notifications_screen.dart';
import '../../features/rider/screens/rider_shell.dart';
import '../../features/rider/screens/home/rider_home_screen.dart';
import '../../features/rider/screens/assignments/rider_assignments_screen.dart';
import '../../features/rider/screens/assignments/rider_assignment_detail_screen.dart';
import '../../features/rider/screens/collect/rider_collect_screen.dart';
import '../../features/rider/screens/ci/rider_ci_upload_screen.dart';
import '../../features/rider/screens/history/rider_history_screen.dart';
import '../../features/rider/screens/profile/rider_profile_screen.dart';
import '../../features/rider/screens/settings/rider_settings_screen.dart';
import '../../features/lender/screens/lender_shell.dart';
import '../../features/lender/screens/home/lender_home_screen.dart';
import '../../features/lender/screens/loans/lender_loans_screen.dart';
import '../../features/lender/screens/loans/lender_loan_detail_screen.dart';
import '../../features/lender/screens/apply/lender_apply_screen.dart';
import '../../features/lender/screens/pay/lender_pay_screen.dart';
import '../../features/lender/screens/alerts/lender_alerts_screen.dart';
import '../../features/lender/screens/profile/lender_profile_screen.dart';
import '../../features/lender/screens/kyc/lender_kyc_screen.dart';
import '../../features/lender/screens/settings/lender_settings_screen.dart';
import '../../features/lender/screens/pay/lender_pay_methods_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: RouteConstants.splash,
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final isSplash = state.matchedLocation == RouteConstants.splash;

      // Wait for auth to initialize — keep showing splash or current page
      if (!authState.initialized) {
        return isSplash ? null : RouteConstants.splash;
      }

      final loggedIn = authState.isAuthenticated;
      final role = authState.role;

      // Redirect away from splash once auth is initialized
      if (isSplash) {
        if (!loggedIn) return RouteConstants.login;
        return _defaultRouteFor(role);
      }

      final isAuthRoute = state.matchedLocation == RouteConstants.login ||
          state.matchedLocation == RouteConstants.register ||
          state.matchedLocation == RouteConstants.forgotPassword ||
          state.matchedLocation == RouteConstants.terms;

      if (!loggedIn) {
        return isAuthRoute ? null : RouteConstants.login;
      }

      if (authState.needsForceChange &&
          state.matchedLocation != RouteConstants.forceChangePassword) {
        return RouteConstants.forceChangePassword;
      }

      if (state.matchedLocation == RouteConstants.forceChangePassword) {
        return null;
      }

      if (isAuthRoute) {
        return _defaultRouteFor(role);
      }

      if (role == UserRole.headManager &&
          !state.matchedLocation.startsWith('/hm')) {
        return RouteConstants.hmDashboard;
      }
      if (role == UserRole.employee &&
          !state.matchedLocation.startsWith('/emp')) {
        return RouteConstants.empDashboard;
      }
      if (role == UserRole.rider &&
          !state.matchedLocation.startsWith('/rider')) {
        return RouteConstants.riderHome;
      }
      if (role == UserRole.lender &&
          !state.matchedLocation.startsWith('/lender')) {
        return RouteConstants.lenderHome;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RouteConstants.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteConstants.login,
        pageBuilder: (ctx, st) => _fadeSlidePage(ctx, st, const LoginScreen()),
      ),
      GoRoute(
        path: RouteConstants.register,
        pageBuilder: (ctx, st) =>
            _fadeSlidePage(ctx, st, const RegisterScreen()),
      ),
      GoRoute(
        path: RouteConstants.forgotPassword,
        pageBuilder: (ctx, st) =>
            _fadeSlidePage(ctx, st, const ForgotPasswordScreen()),
      ),
      GoRoute(
        path: RouteConstants.forceChangePassword,
        pageBuilder: (ctx, st) =>
            _fadeSlidePage(ctx, st, const ForceChangePasswordScreen()),
      ),
      GoRoute(
        path: RouteConstants.terms,
        pageBuilder: (ctx, st) => _fadeSlidePage(ctx, st, const TermsScreen()),
      ),
      ShellRoute(
        builder: (_, __, child) => HmShell(child: child),
        routes: [
          GoRoute(
              path: RouteConstants.hmDashboard,
              builder: (_, __) => const HmDashboardScreen()),
          GoRoute(
              path: RouteConstants.hmLoans,
              builder: (_, __) => const HmLoansScreen()),
          GoRoute(
              path: RouteConstants.hmLoanDetail,
              builder: (_, state) =>
                  HmLoanDetailScreen(id: state.pathParameters['id']!)),
          GoRoute(
              path: RouteConstants.hmPayments,
              builder: (_, __) => const HmPaymentsScreen()),
          GoRoute(
              path: RouteConstants.hmUsers,
              builder: (_, __) => const HmUsersScreen()),
          GoRoute(
              path: RouteConstants.hmUserDetail,
              builder: (_, state) =>
                  HmUserDetailScreen(id: state.pathParameters['id']!)),
          GoRoute(
              path: RouteConstants.hmKyc,
              builder: (_, __) => const HmKycScreen()),
          GoRoute(
              path: RouteConstants.hmAssignments,
              builder: (_, __) => const HmAssignmentsScreen()),
          GoRoute(
              path: RouteConstants.hmAnalytics,
              builder: (_, __) => const HmAnalyticsScreen()),
          GoRoute(
              path: RouteConstants.hmReports,
              builder: (_, __) => const HmReportsScreen()),
          GoRoute(
              path: RouteConstants.hmAudit,
              builder: (_, __) => const HmAuditScreen()),
          GoRoute(
              path: RouteConstants.hmSettings,
              builder: (_, __) => const HmSettingsScreen()),
          GoRoute(
              path: RouteConstants.hmProfile,
              builder: (_, __) => const HmProfileScreen()),
          GoRoute(
              path: RouteConstants.hmNotifications,
              builder: (_, __) => const HmNotificationsScreen()),
        ],
      ),
      ShellRoute(
        builder: (_, __, child) => EmpShell(child: child),
        routes: [
          GoRoute(
              path: RouteConstants.empDashboard,
              builder: (_, __) => const EmpDashboardScreen()),
          GoRoute(
              path: RouteConstants.empLoans,
              builder: (_, __) => const EmpLoansScreen()),
          GoRoute(
              path: RouteConstants.empLoanDetail,
              builder: (_, state) =>
                  EmpLoanDetailScreen(id: state.pathParameters['id']!)),
          GoRoute(
              path: RouteConstants.empPayments,
              builder: (_, __) => const EmpPaymentsScreen()),
          GoRoute(
              path: RouteConstants.empKyc,
              builder: (_, __) => const EmpKycScreen()),
          GoRoute(
              path: RouteConstants.empAssignments,
              builder: (_, __) => const EmpAssignmentsScreen()),
          GoRoute(
              path: RouteConstants.empUsers,
              builder: (_, __) => const EmpUsersScreen()),
          GoRoute(
              path: RouteConstants.empProfile,
              builder: (_, __) => const EmpProfileScreen()),
          GoRoute(
              path: RouteConstants.empNotifications,
              builder: (_, __) => const EmpNotificationsScreen()),
        ],
      ),
      ShellRoute(
        builder: (_, __, child) => RiderShell(child: child),
        routes: [
          GoRoute(
              path: RouteConstants.riderHome,
              builder: (_, __) => const RiderHomeScreen()),
          GoRoute(
              path: RouteConstants.riderAssignments,
              builder: (_, __) => const RiderAssignmentsScreen()),
          GoRoute(
              path: RouteConstants.riderAssignmentDetail,
              builder: (_, state) =>
                  RiderAssignmentDetailScreen(id: state.pathParameters['id']!)),
          GoRoute(
              path: RouteConstants.riderCollect,
              builder: (_, state) =>
                  RiderCollectScreen(id: state.pathParameters['id']!)),
          GoRoute(
              path: RouteConstants.riderCiUpload,
              builder: (_, state) => RiderCiUploadScreen(
                  assignmentId: state.pathParameters['id']!)),
          GoRoute(
              path: RouteConstants.riderHistory,
              builder: (_, __) => const RiderHistoryScreen()),
          GoRoute(
              path: RouteConstants.riderProfile,
              builder: (_, __) => const RiderProfileScreen()),
          GoRoute(
              path: RouteConstants.riderSettings,
              builder: (_, __) => const RiderSettingsScreen()),
        ],
      ),
      ShellRoute(
        builder: (_, __, child) => LenderShell(child: child),
        routes: [
          GoRoute(
              path: RouteConstants.lenderHome,
              builder: (_, __) => const LenderHomeScreen()),
          GoRoute(
              path: RouteConstants.lenderLoans,
              builder: (_, __) => const LenderLoansScreen()),
          GoRoute(
              path: RouteConstants.lenderLoanDetail,
              builder: (_, state) =>
                  LenderLoanDetailScreen(id: state.pathParameters['id']!)),
          GoRoute(
              path: RouteConstants.lenderApply,
              builder: (_, __) => const LenderApplyScreen()),
          GoRoute(
              path: RouteConstants.lenderPay,
              builder: (_, state) =>
                  LenderPayScreen(id: state.pathParameters['id']!)),
          GoRoute(
              path: RouteConstants.lenderAlerts,
              builder: (_, __) => const LenderAlertsScreen()),
          GoRoute(
              path: RouteConstants.lenderProfile,
              builder: (_, __) => const LenderProfileScreen()),
          GoRoute(
              path: RouteConstants.lenderKyc,
              builder: (_, __) => const LenderKycScreen()),
          GoRoute(
              path: RouteConstants.lenderSettings,
              builder: (_, __) => const LenderSettingsScreen()),
          GoRoute(
              path: RouteConstants.lenderPayMethods,
              builder: (_, __) => const LenderPayMethodsScreen()),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

String _defaultRouteFor(UserRole? role) {
  switch (role) {
    case UserRole.headManager:
      return RouteConstants.hmDashboard;
    case UserRole.employee:
      return RouteConstants.empDashboard;
    case UserRole.rider:
      return RouteConstants.riderHome;
    case UserRole.lender:
    default:
      return RouteConstants.lenderHome;
  }
}

/// Shared slide-up + fade page transition used across all GoRoutes.
CustomTransitionPage<T> _fadeSlidePage<T>(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (_, animation, __, ch) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: animation, child: ch),
      );
    },
  );
}

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}
