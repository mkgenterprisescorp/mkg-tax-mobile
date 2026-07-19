import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

class EntitiesRepository {
  EntitiesRepository(this._api);
  final LaravelApiClient _api;

  List<Map<String, dynamic>>? _listCache;
  DateTime? _listCacheAt;
  static const _listCacheTtl = Duration(seconds: 45);

  Future<List<Map<String, dynamic>>> list({bool force = false}) async {
    if (_api.bearerToken == null) return const [];
    final now = DateTime.now();
    if (!force &&
        _listCache != null &&
        _listCacheAt != null &&
        now.difference(_listCacheAt!) < _listCacheTtl) {
      return _listCache!;
    }
    final res = await _api.get<Map<String, dynamic>>('/api/v1/entities');
    if (!PlatformApi.ok(res)) return const [];
    final rows = PlatformApi.unwrapList(res);
    _listCache = rows;
    _listCacheAt = now;
    return rows;
  }

  Future<Map<String, dynamic>?> create({
    required String entityType,
    required String legalName,
    String? formationState,
  }) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.post<Map<String, dynamic>>(
      '/api/v1/entities',
      data: {
        'entity_type': entityType,
        'legal_name': legalName,
        if (formationState case final state?) 'formation_state': state,
      },
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  Future<Map<String, dynamic>?> show(String entityId) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.get<Map<String, dynamic>>('/api/v1/entities/$entityId');
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  /// Ensure the client has at least one individual entity for tax-year workspaces.
  Future<Map<String, dynamic>?> ensurePrimaryEntity({String legalName = 'Primary filing'}) async {
    final existing = await list();
    if (existing.isNotEmpty) return existing.first;
    final created = await create(entityType: 'individual', legalName: legalName);
    // Invalidate short cache so the next list sees the new entity.
    _listCache = null;
    _listCacheAt = null;
    return created;
  }
}

final entitiesRepositoryProvider = Provider<EntitiesRepository>((ref) {
  return EntitiesRepository(ref.watch(laravelApiClientProvider));
});
