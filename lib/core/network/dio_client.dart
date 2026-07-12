// lib/core/network/dio_client.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import '../constants/supabase_constants.dart';
import 'auth_interceptor.dart';

class DioClient {
  static DioClient? _instance;
  late final Dio _dio;

  DioClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: SupabaseConstants.functionsBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Accept': 'application/json',
          'apikey': SupabaseConstants.anonKey,
        },
      ),
    );

    _dio.interceptors.add(AuthInterceptor());

    if (!kReleaseMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: false,
          requestHeader: false,
          responseHeader: false,
          error: true,
          logPrint: (obj) => print('[DIO] $obj'),
        ),
      );
    }
  }

  factory DioClient() {
    _instance ??= DioClient._internal();
    return _instance!;
  }

  static DioClient get instance => DioClient();

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> uploadMultipart<T>(
    String path,
    FormData formData, {
    void Function(int, int)? onSendProgress,
  }) async {
    return _dio.post<T>(
      path,
      data: formData,
      options: Options(
        receiveTimeout: const Duration(minutes: 5),
        sendTimeout: const Duration(minutes: 5),
      ),
      onSendProgress: onSendProgress,
    );
  }
}
