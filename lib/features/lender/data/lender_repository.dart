// lib/features/lender/data/lender_repository.dart
//
// FIX #8 — KYC submit 403 / connection error:
//   ROOT CAUSE 1: getMyKyc() was calling '/kyc-review/list/mine' which
//     does NOT exist — the correct route is '/kyc-submit/mine' (GET).
//     This caused a 404 that surfaced as a connection error in some builds.
//   ROOT CAUSE 2: submitKyc() calls DioClient.uploadMultipart which
//     previously set `Content-Type: multipart/form-data` WITHOUT the
//     required boundary string. That has been fixed in dio_client.dart.
//     The Supabase Edge Function (kyc-submit/index.ts) calls req.formData()
//     which requires the boundary to be in Content-Type — without it the
//     Deno runtime throws, producing the XMLHttpRequest connection error.
//
// All sensitive operations (KYC processing, file storage, encryption) remain
// in the TypeScript Edge Functions. Flutter only prepares FormData and sends it.

import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_response.dart';
import '../../../shared/models/loan_model.dart';
import '../../../shared/models/payment_model.dart';
import '../../../shared/models/kyc_model.dart';
import '../../../shared/models/notification_model.dart';
import '../../../shared/models/loan_term_tier_model.dart';

class LenderRepository {
  final DioClient _client = DioClient.instance;

  // ── Loans ─────────────────────────────────────────────────────────────────

  Future<ApiResponse<List<LoanModel>>> listMyLoans() async {
    try {
      final res = await _client
          .get(ApiEndpoints.loanApplyList, queryParameters: {'scope': 'mine'});
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

  /// Uploads the co-maker signature PNG and returns the storage URL.
  /// All file storage is handled by the loan-apply Edge Function in TypeScript.
  Future<ApiResponse<String>> uploadComakerSignature(Uint8List bytes) async {
    try {
      final formData = FormData.fromMap({
        'signature': MultipartFile.fromBytes(
          bytes,
          filename: 'signature.png',
          contentType: DioMediaType('image', 'png'),
        ),
      });
      // FIX: DioClient.uploadMultipart no longer sets manual Content-Type
      // so Dio correctly includes multipart boundary in the header.
      final res = await _client.uploadMultipart(
          '/loan-apply/upload-signature', formData);
      final data = res.data as Map<String, dynamic>;
      return ApiResponse.ok(data['signature_url'] as String);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<List<LoanSchedule>>> getSchedule(String loanId) async {
    try {
      final res = await _client
          .get(ApiEndpoints.loanSchedule, queryParameters: {'loan_id': loanId});
      final list = ((res.data as Map)['schedule'] as List)
          .map((s) => LoanSchedule.fromJson(s as Map<String, dynamic>))
          .toList();
      return ApiResponse.ok(list);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  /// Submits a loan application. All business logic (interest calculation,
  /// co-maker validation, term assignment) runs in loan-apply Edge Function.
  Future<ApiResponse<void>> applyLoan(Map<String, dynamic> data) async {
    try {
      await _client.post(ApiEndpoints.loanApply, data: data);
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  // ── Payments ──────────────────────────────────────────────────────────────

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
          .map((m) => SystemPaymentMethod.fromJson(m as Map<String, dynamic>))
          .toList();
      return ApiResponse.ok(list.where((m) => m.isEnabled).toList());
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  // ── KYC ──────────────────────────────────────────────────────────────────

  /// FIX: Was calling '/kyc-review/list/mine' which does not exist.
  /// The correct route is GET /kyc-submit/mine handled by kyc-submit function.
  /// All KYC data retrieval stays in the Edge Function — no direct DB access.
  Future<ApiResponse<KycModel?>> getMyKyc() async {
    try {
      // FIX: ApiEndpoints.kycSubmit = '/kyc-submit', so this resolves to
      // '/kyc-submit/mine' which matches the GET handler in kyc-submit/index.ts
      final res = await _client.get('${ApiEndpoints.kycSubmit}/mine');
      final data = res.data as Map<String, dynamic>;
      if (data['kyc'] == null) return ApiResponse.ok(null);
      return ApiResponse.ok(
          KycModel.fromJson(data['kyc'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  /// Submits KYC documents as multipart form data.
  /// All file uploads to storage, encryption of ID numbers, and KYC record
  /// creation happen exclusively in the kyc-submit Edge Function (TypeScript).
  /// Flutter only builds the FormData payload and calls uploadMultipart.
  ///
  /// FIX: DioClient.uploadMultipart no longer manually sets Content-Type,
  /// so Dio auto-generates `multipart/form-data; boundary=<uuid>`.
  /// Without the boundary the Deno runtime cannot parse req.formData(),
  /// causing the XMLHttpRequest connection error seen in the screenshots.
  Future<ApiResponse<void>> submitKyc(FormData formData) async {
    try {
      await _client.uploadMultipart(ApiEndpoints.kycSubmit, formData);
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  // ── Notifications ─────────────────────────────────────────────────────────

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
      await _client
          .post(ApiEndpoints.notificationMarkRead, data: {'all': true});
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  Future<ApiResponse<void>> markNotificationRead(String id) async {
    try {
      await _client.post(ApiEndpoints.notificationMarkRead,
          data: {'notification_id': id});
      return ApiResponse.ok(null);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }

  // ── Error extraction ──────────────────────────────────────────────────────

  String _err(DioException e) {
    // Network-layer failures — no response received at all
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown) {
      return 'Cannot reach server. Check your internet connection or ensure Edge Functions are deployed.';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Request timed out. Please try again.';
    }
    try {
      final d = e.response?.data;
      if (d is Map) {
        return d['error'] as String? ??
            d['message'] as String? ??
            'Request failed (${e.response?.statusCode})';
      }
    } catch (_) {}
    return e.message ?? 'Request failed';
  }

  Future<ApiResponse<List<LoanTermTierModel>>> getLoanTermTiers() async {
    try {
      final res = await _client.get(ApiEndpoints.systemSettingsTiers);
      final tiers = ((res.data as Map)['tiers'] as List)
          .map((t) => LoanTermTierModel.fromJson(t as Map<String, dynamic>))
          .toList();
      return ApiResponse.ok(tiers);
    } on DioException catch (e) {
      return ApiResponse.fail(_err(e));
    }
  }
}
