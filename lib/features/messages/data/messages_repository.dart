import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

class MessagesRepository {
  MessagesRepository(this._api);
  final LaravelApiClient _api;

  Future<List<Map<String, dynamic>>> threads() async {
    if (_api.bearerToken == null) return const [];
    final res = await _api.get<Map<String, dynamic>>('/api/v1/messages/threads');
    if (!PlatformApi.ok(res)) return const [];
    return PlatformApi.unwrapList(res);
  }

  Future<Map<String, dynamic>?> createThread({
    required String subject,
    required String body,
    String? workspaceId,
    String? entityId,
  }) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.post<Map<String, dynamic>>(
      '/api/v1/messages/threads',
      data: {
        'subject': subject,
        'body': body,
        if (workspaceId != null) 'tax_year_workspace_id': workspaceId,
        if (entityId != null) 'mobile_entity_id': entityId,
      },
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  Future<List<Map<String, dynamic>>> messages(String threadId) async {
    if (_api.bearerToken == null) return const [];
    final res = await _api.get<Map<String, dynamic>>('/api/v1/messages/threads/$threadId');
    if (!PlatformApi.ok(res)) return const [];
    return PlatformApi.unwrapList(res);
  }

  Future<Map<String, dynamic>?> send(String threadId, String body) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.post<Map<String, dynamic>>(
      '/api/v1/messages/threads/$threadId',
      data: {'body': body},
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }
}

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  return MessagesRepository(ref.watch(laravelApiClientProvider));
});
