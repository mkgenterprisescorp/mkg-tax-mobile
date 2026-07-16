import 'package:dio/dio.dart';

/// Helpers for Laravel `{ "data": ... }` / `{ "error": ... }` envelopes.
class PlatformApi {
  static dynamic unwrap(Response<dynamic> res) {
    final body = res.data;
    if (body is Map && body['data'] != null) return body['data'];
    return body;
  }

  static Map<String, dynamic>? unwrapMap(Response<dynamic> res) {
    final data = unwrap(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  static List<Map<String, dynamic>> unwrapList(Response<dynamic> res) {
    final data = unwrap(res);
    if (data is List) {
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return const [];
  }

  static bool ok(Response<dynamic> res) => (res.statusCode ?? 500) < 400;
}
