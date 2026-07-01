// lib/core/constants/route_constants.dart

class RouteConstants {
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String forceChangePassword = '/force-change-password';
  static const String terms = '/terms';

  static const String hmShell = '/hm';
  static const String hmDashboard = '/hm/dashboard';
  static const String hmLoans = '/hm/loans';
  static const String hmLoanDetail = '/hm/loans/:id';
  static const String hmPayments = '/hm/payments';
  static const String hmUsers = '/hm/users';
  static const String hmUserDetail = '/hm/users/:id';
  static const String hmKyc = '/hm/kyc';
  static const String hmRiders = '/hm/riders';
  static const String hmAssignments = '/hm/assignments';
  static const String hmAnalytics = '/hm/analytics';
  static const String hmAudit = '/hm/audit';
  static const String hmSettings = '/hm/settings';
  static const String hmProfile = '/hm/profile';
  static const String hmNotifications = '/hm/notifications';

  static const String empShell = '/emp';
  static const String empDashboard = '/emp/dashboard';
  static const String empLoans = '/emp/loans';
  static const String empLoanDetail = '/emp/loans/:id';
  static const String empPayments = '/emp/payments';
  static const String empKyc = '/emp/kyc';
  static const String empAssignments = '/emp/assignments';
  static const String empRiders = '/emp/riders';
  static const String empProfile = '/emp/profile';
  static const String empNotifications = '/emp/notifications';

  static const String riderShell = '/rider';
  static const String riderHome = '/rider/home';
  static const String riderAssignments = '/rider/assignments';
  static const String riderAssignmentDetail = '/rider/assignments/:id';
  static const String riderCollect = '/rider/collect/:id';
  static const String riderHistory = '/rider/history';
  static const String riderProfile = '/rider/profile';

  static const String lenderShell = '/lender';
  static const String lenderHome = '/lender/home';
  static const String lenderLoans = '/lender/loans';
  static const String lenderLoanDetail = '/lender/loans/:id';
  static const String lenderApply = '/lender/apply';
  static const String lenderPay = '/lender/pay/:id';
  static const String lenderAlerts = '/lender/alerts';
  static const String lenderProfile = '/lender/profile';
  static const String lenderKyc = '/lender/kyc';
  static const String lenderSettings = '/lender/settings';
}