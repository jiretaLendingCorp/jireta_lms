// lib/features/lender/data/lender_repository.dart

import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_response.dart';
import '../../../shared/models/loan_model.dart';
import '../../../shared/models/payment_model.dart';
import '../../../shared/models/kyc_model.dart';
import '../../../shared/models/notification_model.dart';

class LenderRepository {
  final DioClient _client = DioClient.instance;

  Future<ApiResponse<List<LoanModel>>> listMyLoans() async {
    try {
      final res = await _client.get(ApiEndpoints.loanApplyList,
          queryParameters: {'scope': 'mine'});
      final list = ((res.data as Map)['loans'] as List)
          .map((l) => LoanModel.fromJson(l as Map<String, dynamic>))
          .toList();
      return ApiResponse.ok(list);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<LoanModel>> getLoan(String id) async {
    try {
      final res = await _client.get('${ApiEndpoints.loanApplyGet}/$id');
      return ApiResponse.ok(
          LoanModel.fromJson(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<List<LoanSchedule>>> getSchedule(String loanId) async {
    try {
      final res = await _client.get(ApiEndpoints.loanSchedule,
          queryParameters: {'loan_id': loanId});
      final list = ((res.data as Map)['schedule'] as List)
          .map((s) => LoanSchedule.fromJson(s as Map<String, dynamic>))
          .toList();
      return ApiResponse.ok(list);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<void>> applyLoan(Map<String, dynamic> data) async {
    try {
      await _client.post(ApiEndpoints.loanApply, data: data);
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<String>> initiatePayment(
      String loanId, String method) async {
    try {
      final res = await _client.post(ApiEndpoints.paymentRecord, data: {
        'loan_id': loanId,
        'method': method,
      });
      final data = res.data as Map<String, dynamic>;
      return ApiResponse.ok(data['payment_url'] as String? ?? '');
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<void>> requestCashCollection(
      String loanId, double amount, DateTime date,
      {double? lat, double? lng}) async {
    try {
      await _client.post(ApiEndpoints.paymentRecord, data: {
        'loan_id': loanId,
        'method': 'cash',
        'amount': amount,
        'collection_date': date.toIso8601String().substring(0, 10),
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      });
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<List<PaymentModel>>> getPaymentHistory(
      String loanId) async {
    try {
      final res = await _client.get(ApiEndpoints.paymentHistory,
          queryParameters: {'loan_id': loanId});
      final list = ((res.data as Map)['payments'] as List)
          .map((p) => PaymentModel.fromJson(p as Map<String, dynamic>))
          .toList();
      return ApiResponse.ok(list);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<List<SystemPaymentMethod>>>
      getAvailablePaymentMethods() async {
    try {
      final res =
          await _client.get('${ApiEndpoints.systemSettings}/payment-methods');
      final list = ((res.data as Map)['methods'] as List)
          .map((m) =>
              SystemPaymentMethod.fromJson(m as Map<String, dynamic>))
          .toList();
      return ApiResponse.ok(
          list.where((m) => m.isEnabled).toList());
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<KycModel?>> getMyKyc() async {
    try {
      final res = await _client
          .get('${ApiEndpoints.kycList}/mine');
      final data = res.data as Map<String, dynamic>;
      if (data['kyc'] == null) return ApiResponse.ok(null);
      return ApiResponse.ok(
          KycModel.fromJson(data['kyc'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<void>> submitKyc(FormData formData) async {
    try {
      await _client.uploadMultipart(ApiEndpoints.kycSubmit, formData);
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<List<NotificationModel>>> listNotifications() async {
    try {
      final res = await _client.get(ApiEndpoints.notifications);
      final list = ((res.data as Map)['notifications'] as List)
          .map((n) => NotificationModel.fromJson(n as Map<String, dynamic>))
          .toList();
      return ApiResponse.ok(list);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<void>> markAllNotificationsRead() async {
    try {
      await _client.post(ApiEndpoints.notificationMarkRead,
          data: {'all': true});
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  String _err(DioException e) {
    try {
      final d = e.response?.data;
      if (d is Map) {
        return d['error'] as String? ?? d['message'] as String? ?? 'Request failed';
      }
    } catch (_) {}
    return e.message ?? 'Request failed';
  }
}