import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

class NotificationsRepository {
  NotificationsRepository(this._api);
  final LaravelApiClient _api;

  Future<({List<Map<String, dynamic>> items, Map<String, dynamic>? policy})> list() async {
    if (_api.bearerToken == null) {
      return (items: const <Map<String, dynamic>>[], policy: null);
    }
    final res = await _api.get<Map<String, dynamic>>('/api/v1/notifications');
    if (!PlatformApi.ok(res)) {
      return (items: const <Map<String, dynamic>>[], policy: null);
    }
    final map = PlatformApi.unwrapMap(res) ?? {};
    final items = (map['items'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const <Map<String, dynamic>>[];
    final policy = map['policy'] is Map ? Map<String, dynamic>.from(map['policy'] as Map) : null;
    return (items: items, policy: policy);
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(laravelApiClientProvider));
});
