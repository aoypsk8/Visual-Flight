import 'package:dio/dio.dart';
import 'package:get_storage/get_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../config/app_env.dart';
import 'api_exception.dart';
import 'api_response.dart';

class ApiClient {
  final Dio _dio;

  ApiClient._(this._dio);

  factory ApiClient.create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppEnv.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (AppEnv.apiKey.isNotEmpty) 'x-api-key': AppEnv.apiKey,
        },
      ),
    );

    dio.interceptors.add(_AuthInterceptor());

    if (!AppEnv.isProduction) {
      dio.interceptors.add(
        PrettyDioLogger(requestHeader: true, requestBody: true, responseBody: true),
      );
    }

    return ApiClient._(dio);
  }

  // ── GET ───────────────────────────────────────────────────────────────────────

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJson,
    Options? options,
  }) =>
      _request('GET', path,
          queryParameters: queryParameters, fromJson: fromJson, options: options);

  // ── POST ──────────────────────────────────────────────────────────────────────

  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJson,
    Options? options,
  }) =>
      _request('POST', path,
          data: data, queryParameters: queryParameters, fromJson: fromJson, options: options);

  // ── PUT ───────────────────────────────────────────────────────────────────────

  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJson,
    Options? options,
  }) =>
      _request('PUT', path,
          data: data, queryParameters: queryParameters, fromJson: fromJson, options: options);

  // ── PATCH ─────────────────────────────────────────────────────────────────────

  Future<ApiResponse<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJson,
    Options? options,
  }) =>
      _request('PATCH', path,
          data: data, queryParameters: queryParameters, fromJson: fromJson, options: options);

  // ── DELETE ────────────────────────────────────────────────────────────────────

  Future<ApiResponse<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJson,
    Options? options,
  }) =>
      _request('DELETE', path,
          data: data, queryParameters: queryParameters, fromJson: fromJson, options: options);

  // ── Upload (multipart) ────────────────────────────────────────────────────────

  Future<ApiResponse<T>> upload<T>(
    String path,
    FormData formData, {
    T Function(dynamic json)? fromJson,
    void Function(int sent, int total)? onSendProgress,
  }) =>
      _request('POST', path,
          data: formData,
          fromJson: fromJson,
          options: Options(contentType: 'multipart/form-data'),
          onSendProgress: onSendProgress);

  // ── Core request ──────────────────────────────────────────────────────────────

  Future<ApiResponse<T>> _request<T>(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJson,
    Options? options,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: (options ?? Options()).copyWith(method: method),
        onSendProgress: onSendProgress,
      );

      return ApiResponse<T>(
        success: true,
        statusCode: response.statusCode,
        message: _pickMessage(response.data),
        data: fromJson != null ? fromJson(response.data) : response.data as T?,
      );
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  String? _pickMessage(dynamic body) =>
      body is Map<String, dynamic> ? body['message'] as String? : null;

  ApiException _toApiException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(message: 'error_timeout');

      case DioExceptionType.connectionError:
        return const ApiException(message: 'error_no_connection');

      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        final body = e.response?.data;
        final serverMessage =
            (body is Map<String, dynamic> ? body['message'] as String? : null);
        final errors =
            body is Map<String, dynamic> ? body['errors'] as Map<String, dynamic>? : null;

        final message = serverMessage ?? _statusMessage(code);
        return ApiException(message: message, statusCode: code, errors: errors);

      default:
        return const ApiException(message: 'error_generic');
    }
  }

  String _statusMessage(int? code) {
    switch (code) {
      case 400: return 'error_bad_request';
      case 401: return 'error_invalid_credentials';
      case 403: return 'error_forbidden';
      case 404: return 'error_not_found';
      case 422: return 'error_validation';
      case 500: return 'error_server';
      default:  return 'error_generic';
    }
  }
}

// ── Auth interceptor ──────────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  final _box = GetStorage();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _box.read<String>('auth_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
