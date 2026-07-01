// lib/features/employee/data/emp_repository.dart

import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_response.dart';
import '../../../shared/models/loan_model.dart';
import '../../../shared/models/payment_model.dart';
import '../../../shared/models/kyc_model.dart';
import '../../../shared/models/assignment_model.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/notification_model.dart';

class EmpRepository {
  final DioClient _client = DioClient.instance;

  Future<ApiResponse<List<LoanModel>>> listLoans({String? status}) async {
    try {
      final res = await _client.get(ApiEndpoints.loanApplyList,
          queryParameters: {if (status != null && status != 'all') 'status': status});
      final loans = ((res.data as Map)['loans'] as List)
          .map((l) => LoanModel.fromJson(l as Map<String, dynamic>)).toList();
      return ApiResponse.ok(loans);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<LoanModel>> getLoan(String id) async {
    try {
      final res = await _client.get('${ApiEndpoints.loanApplyGet}/$id');
      return ApiResponse.ok(LoanModel.fromJson(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<void>> approveLoan(String id, int termDays, String freq) async {
    try {
      await _client.post(ApiEndpoints.loanApprove,
          data: {'loan_id': id, 'term_days': termDays, 'payment_frequency': freq});
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<void>> rejectLoan(String id, String reason) async {
    try {
      await _client.post(ApiEndpoints.loanReject,
          data: {'loan_id': id, 'reason': reason});
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<List<PaymentModel>>> listPayments({String? status}) async {
    try {
      final res = await _client.get(ApiEndpoints.paymentList,
          queryParameters: {if (status != null && status != 'all') 'status': status});
      final payments = ((res.data as Map)['payments'] as List)
          .map((p) => PaymentModel.fromJson(p as Map<String, dynamic>)).toList();
      return ApiResponse.ok(payments);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<void>> verifyPayment(String id) async {
    try {
      await _client.post(ApiEndpoints.paymentVerify, data: {'payment_id': id});
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<void>> rejectPayment(String id, String reason) async {
    try {
      await _client.post(ApiEndpoints.paymentReject,
          data: {'payment_id': id, 'reason': reason});
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<void>> recordCashPayment(Map<String, dynamic> data) async {
    try {
      await _client.post(ApiEndpoints.paymentRecord, data: data);
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<List<KycModel>>> listKyc({String? status}) async {
    try {
      final res = await _client.get(ApiEndpoints.kycList,
          queryParameters: {if (status != null && status != 'all') 'status': status});
      final kycs = ((res.data as Map)['kyc'] as List)
          .map((k) => KycModel.fromJson(k as Map<String, dynamic>)).toList();
      return ApiResponse.ok(kycs);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<void>> approveKyc(String id) async {
    try {
      await _client.post(ApiEndpoints.kycApprove, data: {'kyc_id': id});
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<void>> rejectKyc(String id, String reason) async {
    try {
      await _client.post(ApiEndpoints.kycReject,
          data: {'kyc_id': id, 'reason': reason});
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<List<AssignmentModel>>> listAssignments() async {
    try {
      final res = await _client.get(ApiEndpoints.assignmentList);
      final data = ((res.data as Map)['assignments'] as List)
          .map((a) => AssignmentModel.fromJson(a as Map<String, dynamic>)).toList();
      return ApiResponse.ok(data);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<void>> createAssignment(Map<String, dynamic> data) async {
    try {
      await _client.post(ApiEndpoints.assignmentCreate, data: data);
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<List<AppUser>>> listRiders() async {
    try {
      final res = await _client.get(ApiEndpoints.userList,
          queryParameters: {'role': 'rider'});
      final data = ((res.data as Map)['users'] as List)
          .map((u) => AppUser.fromJson(u as Map<String, dynamic>)).toList();
      return ApiResponse.ok(data);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<void>> createUser(Map<String, dynamic> data) async {
    try {
      await _client.post(ApiEndpoints.userCreate, data: data);
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<List<NotificationModel>>> listNotifications() async {
    try {
      final res = await _client.get(ApiEndpoints.notifications);
      final data = ((res.data as Map)['notifications'] as List)
          .map((n) => NotificationModel.fromJson(n as Map<String, dynamic>)).toList();
      return ApiResponse.ok(data);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  String _err(DioException e) {
    try {
      final d = e.response?.data;
      if (d is Map) return d['error'] as String? ?? d['message'] as String? ?? 'Request failed';
    } catch (_) {}
    return e.message ?? 'Request failed';
  }
}