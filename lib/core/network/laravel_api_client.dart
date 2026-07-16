import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

/// HTTP client for Laravel `/api/v1/*` (Sanctum bearer).
/// Never holds a Neon connection string — Laravel is the only DB boundary.
class LaravelApiClient {
  LaravelApiClient(this.dio);

  final Dio dio;
  String? _bearerToken;

  void setBearerToken(String? token) {
    _bearerToken = token;
    if (token == null || token.isEmpty) {
      dio.options.headers.remove('Authorization');
    } else {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  String? get bearerToken => _bearerToken;

  static LaravelApiClient create({String? baseUrl}) {
    final root = (baseUrl ?? AppConfig.laravelApiRoot);
    final dio = Dio(
      BaseOptions(
        // Prefer production API origin; fall back only for local widget tests.
        baseUrl: root.isEmpty ? 'https://api.financemkgtax.com' : root,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Client': 'mkg-tax-mobile',
        },
        validateStatus: (code) => code != null && code < 500,
      ),
    );
    return LaravelApiClient(dio);
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      dio.get<T>(path, queryParameters: query);

  Future<Response<T>> post<T>(String path, {Object? data}) =>
      dio.post<T>(path, data: data);

  Future<Response<T>> patch<T>(String path, {Object? data}) =>
      dio.patch<T>(path, data: data);

  Future<Response<T>> put<T>(String path, {Object? data}) =>
      dio.put<T>(path, data: data);

  Future<Response<T>> delete<T>(String path) => dio.delete<T>(path);
}

final laravelApiClientProvider = Provider<LaravelApiClient>((ref) {
  return LaravelApiClient.create();
});
