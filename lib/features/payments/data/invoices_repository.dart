import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

class InvoicesRepository {
  InvoicesRepository(this._api);
  final LaravelApiClient _api;

  Future<List<Map<String, dynamic>>> list() async {
    if (_api.bearerToken == null) return const [];
    final res = await _api.get<Map<String, dynamic>>('/api/v1/invoices');
    if (!PlatformApi.ok(res)) return const [];
    return PlatformApi.unwrapList(res);
  }

  Future<List<Map<String, dynamic>>> feeSchedule() async {
    final res = await _api.get<Map<String, dynamic>>('/api/v1/billing/fee-schedule');
    if (!PlatformApi.ok(res)) {
      final fallback = await _api.get<Map<String, dynamic>>('/api/v1/reference/fee-schedule');
      if (!PlatformApi.ok(fallback)) return const [];
      final map = PlatformApi.unwrapMap(fallback);
      final items = map?['items'];
      if (items is! List) return const [];
      return items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    final map = PlatformApi.unwrapMap(res);
    final items = map?['items'];
    if (items is! List) return const [];
    return items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Hosted Stripe Checkout via Laravel → portal. Never collects card data in-app.
  Future<Map<String, dynamic>?> checkout(String invoiceId, {String? idempotencyKey}) async {
    if (_api.bearerToken == null) return null;
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/api/v1/invoices/$invoiceId/checkout',
        options: Options(
          headers: {
            if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
          },
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      final map = PlatformApi.unwrapMap(res);
      if (map != null) return map;
      return _errorMap(res.data);
    } on DioException catch (e) {
      final err = _errorMap(e.response?.data);
      if (err != null) return err;
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> feeCheckout({
    required List<Map<String, dynamic>> services,
    int? taxYear,
    String? idempotencyKey,
  }) async {
    if (_api.bearerToken == null) return null;
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/api/v1/billing/fee-checkout',
        data: {
          'services': services,
          if (taxYear != null) 'tax_year': taxYear,
        },
        options: Options(
          headers: {
            if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
          },
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      final map = PlatformApi.unwrapMap(res);
      if (map != null) return map;
      return _errorMap(res.data);
    } on DioException catch (e) {
      final err = _errorMap(e.response?.data);
      if (err != null) return err;
      rethrow;
    }
  }

  Map<String, dynamic>? _errorMap(dynamic data) {
    if (data is! Map) return null;
    final err = data['error'];
    if (err is Map) return Map<String, dynamic>.from(err);
    return null;
  }
}

final invoicesRepositoryProvider = Provider<InvoicesRepository>((ref) {
  return InvoicesRepository(ref.watch(laravelApiClientProvider));
});
