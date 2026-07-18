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
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/api/v1/invoices/$invoiceId/checkout',
      options: Options(
        headers: {
          if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
        },
      ),
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  Future<Map<String, dynamic>?> feeCheckout({
    required List<Map<String, dynamic>> services,
    int? taxYear,
    String? idempotencyKey,
  }) async {
    if (_api.bearerToken == null) return null;
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
      ),
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }
}

final invoicesRepositoryProvider = Provider<InvoicesRepository>((ref) {
  return InvoicesRepository(ref.watch(laravelApiClientProvider));
});
