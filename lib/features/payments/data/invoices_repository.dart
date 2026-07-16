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

  /// Hosted checkout session stub — never collects card data in-app.
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
}

final invoicesRepositoryProvider = Provider<InvoicesRepository>((ref) {
  return InvoicesRepository(ref.watch(laravelApiClientProvider));
});
