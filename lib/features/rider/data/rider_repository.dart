// lib/features/rider/data/rider_repository.dart

import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_response.dart';
import '../../../shared/models/assignment_model.dart';
import '../../../shared/models/notification_model.dart';

class RiderRepository {
  final DioClient _client = DioClient.instance;

  Future<ApiResponse<List<AssignmentModel>>> listMyAssignments({
    String? status,
  }) async {
    try {
      final res = await _client.get(
        ApiEndpoints.assignmentList,
        queryParameters: {
          'scope': 'mine',
          if (status != null && status != 'all') 'status': status,
        },
      );
      final list = ((res.data as Map)['assignments'] as List)
          .map((a) => AssignmentModel.fromJson(a as Map<String, dynamic>))
          .toList();
      return ApiResponse.ok(list);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<AssignmentModel>> getAssignment(String id) async {
    try {
      final res = await _client.get('${ApiEndpoints.assignmentList}/$id');
      return ApiResponse.ok(
          AssignmentModel.fromJson(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<void>> updateAssignmentStatus(
    String id,
    String status, {
    String? failureReason,
  }) async {
    try {
      await _client.post(ApiEndpoints.assignmentUpdate, data: {
        'assignment_id': id,
        'status': status,
        if (failureReason != null) 'failure_reason': failureReason,
      });
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<void>> submitCollection(
    String assignmentId,
    double amount,
    List<int> receiptBytes,
    String receiptExt,
    String? notes,
  ) async {
    try {
      final formData = FormData.fromMap({
        'assignment_id': assignmentId,
        'amount_collected': amount,
        if (notes != null) 'notes': notes,
        'receipt': MultipartFile.fromBytes(receiptBytes,
            filename: 'receipt.$receiptExt'),
      });
      await _client.uploadMultipart(ApiEndpoints.paymentRecord, formData);
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

  Future<ApiResponse<Map<String, dynamic>>> getMyStats() async {
    try {
      final res = await _client.get('${ApiEndpoints.analytics}/rider-stats');
      return ApiResponse.ok(res.data as Map<String, dynamic>);
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