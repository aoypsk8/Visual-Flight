import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../../config/app_env.dart';

/// Builds configured [Dio] instances for any base URL (reusable across APIs).
class ApiDioFactory {
  ApiDioFactory._();

  static Dio create({
    required String baseUrl,
    Map<String, String>? headers,
    List<Interceptor>? interceptors,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 15),
    bool? enableDebugLog,
  }) {
    final shouldLog = enableDebugLog ?? !AppEnv.isProduction;
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        headers: {
          'Accept': 'application/json',
          ...?headers,
        },
      ),
    );

    if (interceptors != null) {
      dio.interceptors.addAll(interceptors);
    }

    if (shouldLog) {
      dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
        ),
      );
    }

    return dio;
  }
}
