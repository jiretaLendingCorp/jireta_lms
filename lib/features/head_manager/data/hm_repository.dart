// lib/features/head_manager/data/hm_repository.dart

import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_response.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/loan_model.dart';
import '../../../shared/models/payment_model.dart';
import '../../../shared/models/kyc_model.dart';
import '../../../shared/models/assignment_model.dart';
import '../../../shared/models/audit_log_model.dart';
import '../../../shared/models/notification_model.dart';
import '../../../shared/models/loan_term_tier_model.dart';
import '../../../shared/models/report_model.dart';

class HmRepository {
  final DioClient _client = DioClient.instance;

  Future<ApiResponse<List<AppUser>>> listUsers({
    String? role,
    String? search,
    int page = 1,
  }) async {
    try {
      final res = await _client.get(ApiEndpoints.userList, queryParameters: {
        if (role != null) 'role': role,
        if (search != null) 'search': search,
        'page': page,
      });
      final data = res.data as Map<String, dynamic>;
      final users = (data['users'] as List)
          .map((u) => AppUser.fromJson(u as Map<String, dynamic>))
          .toList();
      return ApiResponse.ok(users);
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<AppUser>> getUser(String id) async {
    try {
      final res = await _client.get('${ApiEndpoints.userList}/$id');
      return ApiResponse.ok(AppUser.fromJson(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<void>> createUser(Map<String, dynamic> payload) async {
    try {
      await _client.post(ApiEndpoints.userCreate, data: payload);
      return ApiResponse.ok(null, message: 'User created');
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<void>> updateUser(
      String id, Map<String, dynamic> payload) async {
    try {
      await _client
          .patch(ApiEndpoints.userUpdate, data: {'id': id, ...payload});
      return ApiResponse.ok(null, message: 'User updated');
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<void>> deactivateUser(String id) async {
    try {
      await _client.post(ApiEndpoints.userDeactivate, data: {'id': id});
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<void>> resetUserPassword(String id) async {
    try {
      await _client.post(ApiEndpoints.userResetPassword, data: {'id': id});
      return ApiResponse.ok(null, message: 'Password reset to 12345678');
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<List<LoanModel>>> listLoans({
    String? status,
    String? lenderId,
    int page = 1,
  }) async {
    try {
      final res =
          await _client.get(ApiEndpoints.loanApplyList, queryParameters: {
        if (status != null) 'status': status,
        if (lenderId != null) 'lender_id': lenderId,
        'page': page,
      });
      final data = res.data as Map<String, dynamic>;
      final loans = (data['loans'] as List)
          .map((l) => LoanModel.fromJson(l as Map<String, dynamic>))
          .toList();
      return ApiResponse.ok(loans);
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<LoanModel>> getLoan(String id) async {
    try {
      final res = await _client.get('${ApiEndpoints.loanApplyGet}/$id');
      return ApiResponse.ok(
          LoanModel.fromJson(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<void>> approveLoan(
      String id, int termDays, String frequency) async {
    try {
      await _client.post(ApiEndpoints.loanApprove, data: {
        'loan_id': id,
        'term_days': termDays,
        'payment_frequency': frequency
      });
      return ApiResponse.ok(null, message: 'Loan approved');
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<void>> rejectLoan(String id, String reason) async {
    try {
      await _client.post(ApiEndpoints.loanReject,
          data: {'loan_id': id, 'reason': reason});
      return ApiResponse.ok(null, message: 'Loan rejected');
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<void>> disburseLoan(String id) async {
    try {
      await _client.post(ApiEndpoints.loanDisburse, data: {'loan_id': id});
      return ApiResponse.ok(null, message: 'Loan disbursed');
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<void>> closeLoan(String id) async {
    try {
      await _client.post(ApiEndpoints.loanClose, data: {'loan_id': id});
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<void>> waivePenalty(String loanId, String reason) async {
    try {
      await _client.post(ApiEndpoints.loanWaivePenalty,
          data: {'loan_id': loanId, 'reason': reason});
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<List<PaymentModel>>> listPayments({
    String? status,
    String? loanId,
    int page = 1,
  }) async {
    try {
      final res = await _client.get(ApiEndpoints.paymentList, queryParameters: {
        if (status != null) 'status': status,
        if (loanId != null) 'loan_id': loanId,
        'page': page,
      });
      final data = res.data as Map<String, dynamic>;
      final payments = (data['payments'] as List)
          .map((p) => PaymentModel.fromJson(p as Map<String, dynamic>))
          .toList();
      return ApiResponse.ok(payments);
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<void>> verifyPayment(String id) async {
    try {
      await _client.post(ApiEndpoints.paymentVerify, data: {'payment_id': id});
      return ApiResponse.ok(null, message: 'Payment verified');
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<void>> rejectPayment(String id, String reason) async {
    try {
      await _client.post(ApiEndpoints.paymentReject,
          data: {'payment_id': id, 'reason': reason});
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<List<KycModel>>> listKyc({String? status}) async {
    try {
      final res = await _client.get(ApiEndpoints.kycList, queryParameters: {
        if (status != null) 'status': status,
      });
      final data = res.data as Map<String, dynamic>;
      final kycs = (data['kyc'] as List)
          .map((k) => KycModel.fromJson(k as Map<String, dynamic>))
          .toList();
      return ApiResponse.ok(kycs);
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<void>> approveKyc(String id) async {
    try {
      await _client.post(ApiEndpoints.kycApprove, data: {'kyc_id': id});
      return ApiResponse.ok(null, message: 'KYC approved');
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<void>> rejectKyc(String id, String reason) async {
    try {
      await _client
          .post(ApiEndpoints.kycReject, data: {'kyc_id': id, 'reason': reason});
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<List<AssignmentModel>>> listAssignments({
    String? status,
  }) async {
    try {
      final res = await _client.get(ApiEndpoints.assignmentList,
          queryParameters: {if (status != null) 'status': status});
      final data = res.data as Map<String, dynamic>;
      final assignments = (data['assignments'] as List)
          .map((a) => AssignmentModel.fromJson(a as Map<String, dynamic>))
          .toList();
      return ApiResponse.ok(assignments);
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getAnalyticsKpi() async {
    try {
      final res = await _client.get(ApiEndpoints.analyticsKpi);
      return ApiResponse.ok(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getAnalyticsCharts(
      {String? from, String? to}) async {
    try {
      final res = await _client.get(ApiEndpoints.analyticsCharts,
          queryParameters: {
            if (from != null) 'from': from,
            if (to != null) 'to': to
          });
      return ApiResponse.ok(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<List<AuditLogModel>>> listAuditLogs({
    String? userId,
    String? action,
    String? tableName,
    String? from,
    String? to,
    int page = 1,
  }) async {
    try {
      final res = await _client.get('/analytics/audit', queryParameters: {
        if (userId != null) 'user_id': userId,
        if (action != null) 'action': action,
        if (tableName != null) 'table_name': tableName,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        'page': page,
      });
      final data = res.data as Map<String, dynamic>;
      final logs = (data['logs'] as List)
          .map((l) => AuditLogModel.fromJson(l as Map<String, dynamic>))
          .toList();
      return ApiResponse.ok(logs);
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getSystemSettings() async {
    try {
      final res = await _client.get(ApiEndpoints.systemSettings);
      return ApiResponse.ok(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<void>> updateSystemSettings(
      Map<String, dynamic> settings) async {
    try {
      await _client.post(ApiEndpoints.systemSettingsUpdate, data: settings);
      return ApiResponse.ok(null, message: 'Settings updated');
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<List<NotificationModel>>> listNotifications() async {
    try {
      final res = await _client.get(ApiEndpoints.notifications);
      final data = res.data as Map<String, dynamic>;
      final notifs = (data['notifications'] as List)
          .map((n) => NotificationModel.fromJson(n as Map<String, dynamic>))
          .toList();
      return ApiResponse.ok(notifs);
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<void>> createAssignment(
      Map<String, dynamic> payload) async {
    try {
      await _client.post(ApiEndpoints.assignmentCreate, data: payload);
      return ApiResponse.ok(null, message: 'Assignment created');
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  Future<ApiResponse<List<AppUser>>> listRiders() async {
    try {
      final res = await _client
          .get(ApiEndpoints.userList, queryParameters: {'role': 'rider'});
      final data = res.data as Map<String, dynamic>;
      final users = (data['users'] as List)
          .map((u) => AppUser.fromJson(u as Map<String, dynamic>))
          .toList();
      return ApiResponse.ok(users);
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  /// Returns lenders with active/pending/approved loans for assignment dropdown.
  /// Calls GET /loan-apply/active-lenders via Dio (auth header attached).
  Future<ApiResponse<List<dynamic>>> getActiveLenders() async {
    try {
      final res = await _client.get(ApiEndpoints.loanApplyActiveLenders);
      final data = res.data as Map<String, dynamic>;
      return ApiResponse.ok((data['lenders'] as List));
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  /// Returns lenders whose KYC is pending/under_review for CI assignment.
  /// Calls GET /kyc-review/pending-lenders via Dio.
  Future<ApiResponse<List<dynamic>>> getKycPendingLenders() async {
    try {
      final res = await _client.get(ApiEndpoints.kycPendingLenders);
      final data = res.data as Map<String, dynamic>;
      return ApiResponse.ok((data['lenders'] as List));
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  /// Get a single KYC submission with full details for HM/employee review.
  Future<ApiResponse<Map<String, dynamic>>> getKycDetail(String kycId) async {
    try {
      final res = await _client.get('${ApiEndpoints.kycGet}/$kycId');
      return ApiResponse.ok(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  /// Get a single loan with full details for HM/employee review.
  Future<ApiResponse<Map<String, dynamic>>> getLoanDetail(String loanId) async {
    try {
      final res = await _client.get('${ApiEndpoints.loanApplyGet}/$loanId');
      return ApiResponse.ok(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  /// Fetches all loan term tiers. Calls GET /system-settings/tiers via Dio.
  Future<ApiResponse<List<LoanTermTierModel>>> listSystemTiers() async {
    try {
      final res = await _client.get(ApiEndpoints.systemSettingsTiers);
      final data = res.data as Map<String, dynamic>;
      final tiers = (data['tiers'] as List)
          .map((t) => LoanTermTierModel.fromJson(t as Map<String, dynamic>))
          .toList();
      return ApiResponse.ok(tiers);
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  /// Updates a single loan term tier. Calls POST /system-settings/tiers/update via Dio.
  Future<ApiResponse<void>> updateSystemTier(
      Map<String, dynamic> payload) async {
    try {
      await _client.post(ApiEndpoints.systemSettingsTiersUpdate, data: payload);
      return ApiResponse.ok(null, message: 'Tier updated');
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  /// Generates a typed analytics report. Calls GET /analytics/report via Dio.
  Future<ApiResponse<ReportModel>> generateReport({
    required String type,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final res = await _client.get(
        ApiEndpoints.analyticsReport,
        queryParameters: {
          'type': type,
          if (dateFrom != null) 'date_from': dateFrom,
          if (dateTo != null) 'date_to': dateTo,
        },
      );
      return ApiResponse.ok(
          ReportModel.fromJson(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return ApiResponse.fail(_extractError(e));
    }
  }

  String _extractError(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map)
        return data['error'] as String? ??
            data['message'] as String? ??
            'Request failed';
    } catch (_) {}
    return e.message ?? 'Request failed';
  }
}
