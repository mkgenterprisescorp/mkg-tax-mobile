import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

class Ca540Repository {
  Ca540Repository(this._api);
  final LaravelApiClient _api;

  Future<Map<String, dynamic>> calculate(Map<String, dynamic> payload) async {
    if (_api.bearerToken == null) throw StateError('Sign in required for Form 540 calculation');
    final res = await _api.post<Map<String, dynamic>>('/api/v1/ca540/calculate', data: payload);
    if (!PlatformApi.ok(res)) throw StateError('CA Form 540 calculation failed');
    return PlatformApi.unwrapMap(res) ?? {};
  }

  Future<Map<String, dynamic>?> fromOrganizer(String workspaceId) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/tax-year-workspaces/$workspaceId/organizer/ca540-estimate',
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }
}

final ca540RepositoryProvider = Provider<Ca540Repository>((ref) {
  return Ca540Repository(ref.watch(laravelApiClientProvider));
});
