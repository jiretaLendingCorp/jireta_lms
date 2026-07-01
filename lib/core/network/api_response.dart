// lib/core/network/api_response.dart

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? error;
  final int? statusCode;

  const ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.error,
    this.statusCode,
  });

  factory ApiResponse.ok(T data, {String? message}) => ApiResponse(
        success: true,
        data: data,
        message: message,
        statusCode: 200,
      );

  factory ApiResponse.fail(String error, {int? statusCode}) => ApiResponse(
        success: false,
        error: error,
        statusCode: statusCode ?? 400,
      );

  bool get isOk => success && data != null;
}