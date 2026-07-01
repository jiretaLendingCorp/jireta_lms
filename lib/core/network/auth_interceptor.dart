// lib/core/network/auth_interceptor.dart

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/supabase_constants.dart';

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
          }
        } catch (_) {
          options.headers['Authorization'] =
              'Bearer ${session.accessToken}';
        }
      } else {
        options.headers['Authorization'] =
            'Bearer ${session.accessToken}';
      }
    }

    options.headers['apikey'] = SupabaseConstants.anonKey;
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      Supabase.instance.client.auth.signOut();
    }
    handler.next(err);
  }
}