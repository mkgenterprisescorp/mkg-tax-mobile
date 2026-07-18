import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

class AddressRepository {
  AddressRepository(this._api);
  final LaravelApiClient _api;

  Future<List<Map<String, dynamic>>> suggest(String query, {String mode = 'individual'}) async {
    if (_api.bearerToken == null || query.trim().length < 3) return const [];
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/address/autocomplete',
      query: {'q': query.trim(), 'mode': mode},
    );
    if (!PlatformApi.ok(res)) return const [];
    final map = PlatformApi.unwrapMap(res);
    final suggestions = map?['suggestions'];
    if (suggestions is! List) return const [];
    return suggestions.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>?> details(String placeId) async {
    if (_api.bearerToken == null || placeId.isEmpty) return null;
    final res = await _api.get<Map<String, dynamic>>('/api/v1/address/details/$placeId');
    if (!PlatformApi.ok(res)) return null;
    final map = PlatformApi.unwrapMap(res);
    final details = map?['details'];
    if (details is Map) return Map<String, dynamic>.from(details);
    return map;
  }
}

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return AddressRepository(ref.watch(laravelApiClientProvider));
});
