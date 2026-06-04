import 'package:dio/dio.dart';

import '../../config/api_urls.dart';
import 'api_dio_factory.dart';

/// HTTP client for Mapbox REST APIs — separate from FocusFlight [ApiClient].
class MapboxApiClient {
  final Dio _dio;

  MapboxApiClient._(this._dio);

  factory MapboxApiClient.create() {
    return MapboxApiClient._(
      ApiDioFactory.create(
        baseUrl: ApiHosts.mapbox,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
  }

  Future<Map<String, dynamic>?> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
      );
      return response.data;
    } on DioException {
      return null;
    }
  }
}
