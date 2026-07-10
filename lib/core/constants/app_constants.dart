// lib/core/constants/app_constants.dart

class AppConstants {
  static const String appName = 'Jireta Loans';
  static const String companyName = 'Jireta Loans & Credit Corp Inc.';
  static const String appVersion = '1.0.0';

  static const double minLoanAmount = 3000;
  static const double maxLoanAmount = 500000;
  static const double interestRate = 0.20;
  static const double penaltyRate = 0.20;
  static const int penaltyGraceDays = 30;

  static const String defaultStaffPassword = '12345678';
  static const int webBreakpoint = 900;

  static const double sidebarWidth = 260;
  static const double sidebarCollapsedWidth = 72;

  static const double borderRadius = 12;
  static const double cardRadius = 16;
  static const double buttonRadius = 10;

  static const Duration animDuration = Duration(milliseconds: 250);
  static const Duration snackDuration = Duration(seconds: 3);
}