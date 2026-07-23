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

  /// True when HTTP status is 2xx/3xx and the body is not an error-shaped
  /// `{data: {error: ...}}` / `{error: ...}` envelope (bridge sometimes
  /// historically returned those under HTTP 200).
  static bool ok(Response<dynamic> res) {
    if ((res.statusCode ?? 500) >= 400) return false;
    final body = res.data;
    if (body is Map && body['error'] != null) return false;
    final data = body is Map ? body['data'] : null;
    if (data is Map && data['error'] != null) return false;
    return true;
  }
}
