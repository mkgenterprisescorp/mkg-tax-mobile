import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

class TasksRepository {
  TasksRepository(this._api);
  final LaravelApiClient _api;

  Future<List<Map<String, dynamic>>> list(String workspaceId) async {
    if (_api.bearerToken == null) return const [];
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/tax-year-workspaces/$workspaceId/tasks',
    );
    if (!PlatformApi.ok(res)) return const [];
    return PlatformApi.unwrapList(res);
  }

  Future<Map<String, dynamic>?> create({
    required String workspaceId,
    required String title,
    String? href,
  }) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.post<Map<String, dynamic>>(
      '/api/v1/tax-year-workspaces/$workspaceId/tasks',
      data: {
        'title': title,
        if (href != null) 'href': href,
      },
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }
}

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository(ref.watch(laravelApiClientProvider));
});
