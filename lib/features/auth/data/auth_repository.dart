// lib/features/auth/data/auth_repository.dart

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../shared/models/app_user.dart';

class AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final DioClient _client = DioClient.instance;

  Future<String?> registerLender({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? middleName,
    String? phone,
    String? birthday,
  }) async {
    try {
      await _client.post(
        ApiEndpoints.authRegisterLender,
        data: {
          'email': email.trim(),
          'password': password,
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          if (middleName != null && middleName.trim().isNotEmpty)
            'middle_name': middleName.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          if (birthday != null && birthday.trim().isNotEmpty)
            'birthday': birthday.trim(),
        },
      );
      return null;
    } on DioException catch (e) {
      return _extractError(e);
    } catch (_) {
      return 'Registration failed';
    }
  }

  /// Fetches the caller's own profile via the auth-profile Edge Function
  /// (Dio, not a direct Supabase table query) -- consistent with the rest
  /// of the app's "Flutter talks to Postgres only through Edge Functions"
  /// rule. Throws on failure instead of silently returning null, so a
  /// transient network/server error is never mistaken for "not logged in"
  /// by the caller.
  Future<AppUser> getProfile(String userId) async {
    final res = await _client.get(ApiEndpoints.authProfile);
    final data = res.data as Map<String, dynamic>;
    final profile = data['profile'] as Map<String, dynamic>?;
    if (profile == null) {
      throw Exception('Profile not found for this account');
    }
    return AppUser.fromJson(profile);
  }

  Future<String?> changePassword(String current, String newPassword) async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) return 'Not authenticated';
      await _client.post(
        ApiEndpoints.authPasswordChange,
        data: {
          'current_password': current,
          'new_password': newPassword,
        },
      );
      return null;
    } on DioException catch (e) {
      return _extractError(e);
    } catch (_) {
      return 'Failed to change password';
    }
  }

  Future<String?> updateProfile(Map<String, dynamic> updates) async {
    try {
      await _client.patch(ApiEndpoints.authProfileUpdate, data: updates);
      return null;
    } on DioException catch (e) {
      return _extractError(e);
    } catch (_) {
      return 'Failed to update profile';
    }
  }

  Future<String?> uploadAvatar(
      String userId, Uint8List bytes, String ext) async {
    try {
      // Normalise ext so 'jpg' → 'jpeg' for the MIME type
      final mime = ext.toLowerCase() == 'jpg' ? 'jpeg' : ext.toLowerCase();
      final formData = FormData.fromMap({
        'avatar': MultipartFile.fromBytes(
          bytes,
          filename: 'avatar.$ext',
          contentType: DioMediaType('image', mime),
        ),
      });
      await _client.uploadMultipart(ApiEndpoints.authAvatarUpload, formData);
      return null;
    } on DioException catch (e) {
      return _extractError(e);
    } catch (_) {
      return 'Failed to upload avatar';
    }
  }

  /// Sends a password reset via Resend-backed Supabase email link, or an SMS
  /// OTP via Semaphore PH, depending on which contact method is provided.
  /// Routed through the auth-profile Edge Function (sensitive business logic
  /// stays in TypeScript) rather than calling Supabase Auth directly.
  Future<String?> sendForgotPassword({String? email, String? phone}) async {
    try {
      await _client.post(
        ApiEndpoints.authForgotPassword,
        data: {
          if (email != null) 'email': email.trim(),
          if (phone != null) 'phone': phone.trim(),
        },
      );
      return null;
    } on DioException catch (e) {
      return _extractError(e);
    }
  }

  /// Verifies the SMS OTP and sets the new password — all via the
  /// auth-profile Edge Function's public /reset-password route.
  Future<String?> resetPasswordWithOtp({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    try {
      await _client.post(
        ApiEndpoints.authPasswordReset,
        data: {
          'phone': phone.trim(),
          'otp': otp.trim(),
          'new_password': newPassword,
        },
      );
      return null;
    } on DioException catch (e) {
      return _extractError(e);
    }
  }

  String _extractError(DioException e) {
    // Network-layer failures (no response from server at all)
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown) {
      return 'Cannot reach server. Check your internet connection or ensure Edge Functions are deployed.';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Request timed out. Please try again.';
    }
    try {
      final data = e.response?.data;
      if (data is Map) {
        return data['error'] as String? ??
            data['message'] as String? ??
            'Request failed (${e.response?.statusCode})';
      }
    } catch (_) {}
    return e.message ?? 'Request failed';
  }
}
