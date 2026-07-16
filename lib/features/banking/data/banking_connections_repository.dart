import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

/// Phase 6 — banking connection stubs only. No credentials, no money movement.
class BankingConnectionsRepository {
  BankingConnectionsRepository(this._api);
  final LaravelApiClient _api;

  Future<Map<String, dynamic>?> connections(String entityId) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/entities/$entityId/banking-connections',
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  Future<Map<String, dynamic>?> beginKyc(String entityId) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.post<Map<String, dynamic>>(
      '/api/v1/entities/$entityId/banking-connections/kyc',
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }
}

final bankingConnectionsRepositoryProvider = Provider<BankingConnectionsRepository>((ref) {
  return BankingConnectionsRepository(ref.watch(laravelApiClientProvider));
});
