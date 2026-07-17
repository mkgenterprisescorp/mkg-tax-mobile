import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

/// Server-enforced entitlements. Never gate security/organizer on a local flag alone.
class EntitlementsRepository {
  EntitlementsRepository(this._api);
  final LaravelApiClient _api;

  Future<Map<String, dynamic>?> snapshot() async {
    if (_api.bearerToken == null) return null;
    final res = await _api.get<Map<String, dynamic>>('/api/v1/entitlements');
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  bool featureEnabled(Map<String, dynamic>? snapshot, String key) {
    final features = snapshot?['features'];
    if (features is! Map) return false;
    return features[key] == true;
  }
}

final entitlementsRepositoryProvider = Provider<EntitlementsRepository>((ref) {
  return EntitlementsRepository(ref.watch(laravelApiClientProvider));
});
