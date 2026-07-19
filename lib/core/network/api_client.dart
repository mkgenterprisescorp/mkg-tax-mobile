import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'cookie_jar_factory.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('ApiClient must be overridden in main() after init');
});

class ApiClient {
  ApiClient(this.dio, this.cookieJar);

  final Dio dio;
  final CookieJar cookieJar;

  static Future<ApiClient> create() async {
    final jar = await createAppCookieJar();

    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiRoot,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          'X-Client': 'mkg-tax-mobile',
        },
        validateStatus: (code) => code != null && code < 500,
      ),
    );
    dio.interceptors.add(CookieManager(jar));
    return ApiClient(dio, jar);
  }

  /// In-memory client for widget/unit tests (no disk cookie jar).
  factory ApiClient.memory({String baseUrl = 'https://app.mkgtaxconsultants.com/api/v1'}) {
    final jar = CookieJar();
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        validateStatus: (code) => code != null && code < 500,
      ),
    );
    dio.interceptors.add(CookieManager(jar));
    return ApiClient(dio, jar);
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) {
    return dio.get<T>(path, queryParameters: query);
  }

  Future<Response<T>> post<T>(String path, {Object? data, Options? options}) {
    return dio.post<T>(path, data: data, options: options);
  }

  Future<Response<T>> put<T>(String path, {Object? data}) {
    return dio.put<T>(path, data: data);
  }

  Future<Response<T>> delete<T>(String path) {
    return dio.delete<T>(path);
  }

  Future<Response<T>> postMultipart<T>(
    String path, {
    required FormData formData,
  }) {
    return dio.post<T>(
      path,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<void> clearSession() async {
    await cookieJar.deleteAll();
  }
}
