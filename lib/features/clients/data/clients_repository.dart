import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

class ClientsRepository {
  ClientsRepository(this._api);
  final LaravelApiClient _api;

  Future<Map<String, dynamic>?> me() async {
    if (_api.bearerToken == null) return null;
    final res = await _api.get<Map<String, dynamic>>('/api/v1/clients/me');
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  Future<Map<String, dynamic>?> update(Map<String, dynamic> body) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.patch<Map<String, dynamic>>('/api/v1/clients/me', data: body);
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }
}

final clientsRepositoryProvider = Provider<ClientsRepository>((ref) {
  return ClientsRepository(ref.watch(laravelApiClientProvider));
});
