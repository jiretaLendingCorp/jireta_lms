// lib/core/network/api_endpoints.dart

class ApiEndpoints {
  static const String authProfile = '/auth-profile';
  static const String authRegisterLender = '/auth-profile/register-lender';
  static const String authProfileUpdate = '/auth-profile/update';
  static const String authAvatarUpload = '/auth-profile/upload-avatar';
  static const String authPasswordChange = '/auth-profile/change-password';
  static const String authPasswordReset = '/auth-profile/reset-password';
  static const String authForgotPassword = '/auth-profile/forgot-password';

  static const String userCreate = '/user-create';
  static const String userUpdate = '/user-update';
  static const String userList = '/user-update/list';
  static const String userDeactivate = '/user-update/deactivate';
  static const String userResetPassword = '/user-update/reset-password';

  static const String loanApply = '/loan-apply';
  static const String loanApplyComaker = '/loan-apply/comaker';
  static const String loanApplyList = '/loan-apply/list';
  static const String loanApplyGet = '/loan-apply/get';

  static const String loanApprove = '/loan-approve';
  static const String loanReject = '/loan-reject';
  static const String loanDisburse = '/loan-disburse';
  static const String loanClose = '/loan-disburse/close';
  static const String loanDefault = '/loan-disburse/default';
  static const String loanWaivePenalty = '/loan-disburse/waive-penalty';
  static const String loanSchedule = '/loan-disburse/schedule';

  static const String paymentRecord = '/payment-record';
  static const String paymentVerify = '/payment-verify';
  static const String paymentReject = '/payment-verify/reject';
  static const String paymentList = '/payment-record/list';
  static const String paymentHistory = '/payment-record/history';

  static const String kycSubmit = '/kyc-submit';
  static const String kycResubmit = '/kyc-submit/resubmit';
  static const String kycList = '/kyc-review/list';
  static const String kycApprove = '/kyc-review/approve';
  static const String kycReject = '/kyc-review/reject';

  static const String assignmentCreate = '/assignment-create';
  static const String assignmentUpdate = '/assignment-update';
  static const String assignmentList = '/assignment-create/list';
  static const String assignmentCancel = '/assignment-update/cancel';

  static const String systemSettings = '/system-settings';
  static const String systemSettingsUpdate = '/system-settings/update';
  static const String systemSettingsTiers = '/system-settings/tiers';
  static const String systemSettingsTiersUpdate =
      '/system-settings/tiers/update';

  static const String analytics = '/analytics';
  static const String analyticsKpi = '/analytics/kpi';
  static const String analyticsCharts = '/analytics/charts';
  static const String analyticsReport = '/analytics/report';

  static const String notifications = '/send-notification/list';
  static const String notificationMarkRead = '/send-notification/mark-read';

  static const String fcmRegister = '/fcm-register';
  static const String fcmUnregister = '/fcm-register/unregister';

  static const String penaltyCompute = '/penalty-compute';
  // Loan-apply sub-routes (new)
  static const String loanApplyActiveLenders = '/loan-apply/active-lenders';
  static const String loanApplyUploadSignature = '/loan-apply/upload-signature';

  // KYC sub-routes (new)
  static const String kycGet = '/kyc-review/get';
  static const String kycMySubmission = '/kyc-submit/my';
  static const String kycPendingLenders = '/kyc-review/pending-lenders';

  // KYC sub-routes
  static const String kycGetDetail = '/kyc-review/get';

  // User sub-routes
  static const String userGetDetail = '/user-update/get';
  static const String userReactivate = '/user-update/reactivate';
  static const String userCompleteForceChg =
      '/user-update/complete-force-change';
}
