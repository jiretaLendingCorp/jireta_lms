// lib/core/network/auth_interceptor.dart
// FIX: When no user session exists (e.g. during registration), Supabase
// Gateway still requires an Authorization header. We fall back to
// `Bearer <anon_key>` so public Edge Function routes (like /register-lender)
// are not rejected with 401 UNAUTHORIZED_NO_AUTH_HEADER.

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/supabase_constants.dart';
import '../services/connectivity_service.dart';

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      final isExpired =
          session.expiresAt != null &&
          DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)
              .isBefore(DateTime.now().add(const Duration(minutes: 1)));

      if (isExpired) {
        try {
          final refreshed =
              await Supabase.instance.client.auth.refreshSession();
          if (refreshed.session != null) {
            options.headers['Authorization'] =
                'Bearer ${refreshed.session!.accessToken}';
          } else {
            // Refresh failed: fall back to anon key so public routes work
            options.headers['Authorization'] =
                'Bearer ${SupabaseConstants.anonKey}';
          }
        } catch (_) {
          options.headers['Authorization'] =
              'Bearer ${session.accessToken}';
        }
      } else {
        options.headers['Authorization'] =
            'Bearer ${session.accessToken}';
      }
    } else {
      // FIX: No user session — use anon key so Supabase Gateway lets the
      // request through to public Edge Function routes like /register-lender.
      options.headers['Authorization'] =
          'Bearer ${SupabaseConstants.anonKey}';
    }

    options.headers['apikey'] = SupabaseConstants.anonKey;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    ConnectivityService.instance.setOnline(true);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.unknown) {
      ConnectivityService.instance.setOnline(false);
    } else {
      ConnectivityService.instance.setOnline(true);
    }
    // FIX: Only sign out on 401 when there WAS a valid session (token expired).
    // Do NOT sign out on 401 for public routes (register, forgot-password).
    if (err.response?.statusCode == 401) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        Supabase.instance.client.auth.signOut();
      }
    }
    handler.next(err);
  }
}