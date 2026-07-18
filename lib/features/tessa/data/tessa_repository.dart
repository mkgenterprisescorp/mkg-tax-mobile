import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/portal_repository.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

class TessaRepository {
  TessaRepository(this._api, this._portal);
  final LaravelApiClient _api;
  final PortalRepository _portal;

  Future<List<Map<String, dynamic>>> listConversations() async {
    if (AppConfig.usesLaravelAuth && _api.bearerToken != null) {
      final res = await _api.get<Map<String, dynamic>>('/api/v1/tessa/conversations');
      if (!PlatformApi.ok(res)) return const [];
      final map = PlatformApi.unwrapMap(res);
      final rows = map?['conversations'];
      if (rows is! List) return const [];
      return rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return _portal.listConversations();
  }

  Future<Map<String, dynamic>> createConversation({String title = 'Mobile TaxPro Assist'}) async {
    if (AppConfig.usesLaravelAuth && _api.bearerToken != null) {
      final res = await _api.post<Map<String, dynamic>>(
        '/api/v1/tessa/conversations',
        data: {'title': title},
      );
      if (!PlatformApi.ok(res)) throw StateError('Create conversation failed');
      return PlatformApi.unwrapMap(res) ?? {};
    }
    return _portal.createConversation(title: title);
  }

  Future<Map<String, dynamic>?> getConversation(dynamic id) async {
    if (AppConfig.usesLaravelAuth && _api.bearerToken != null) {
      final res = await _api.get<Map<String, dynamic>>('/api/v1/tessa/conversations/$id');
      if (!PlatformApi.ok(res)) return null;
      return PlatformApi.unwrapMap(res);
    }
    return _portal.getConversation(id);
  }

  Future<String> sendMessage(dynamic id, String content) async {
    if (AppConfig.usesLaravelAuth && _api.bearerToken != null) {
      final res = await _api.post<Map<String, dynamic>>(
        '/api/v1/tessa/conversations/$id/messages',
        data: {'content': content},
      );
      if (!PlatformApi.ok(res)) throw StateError('TESSA send failed');
      final map = PlatformApi.unwrapMap(res);
      return map?['reply']?.toString() ?? '';
    }
    return _portal.sendAiMessage(id, content);
  }
}

final tessaRepositoryProvider = Provider<TessaRepository>((ref) {
  return TessaRepository(
    ref.watch(laravelApiClientProvider),
    ref.watch(portalRepositoryProvider),
  );
});
