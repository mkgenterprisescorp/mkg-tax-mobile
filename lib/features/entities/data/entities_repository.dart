import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

class EntitiesRepository {
  EntitiesRepository(this._api);
  final LaravelApiClient _api;

  List<Map<String, dynamic>>? _listCache;
  DateTime? _listCacheAt;
  static const _listCacheTtl = Duration(seconds: 45);

  /// Entity create/list can take several seconds on staging Neon.
  static final _entityWriteOptions = Options(
    sendTimeout: const Duration(seconds: 45),
    receiveTimeout: const Duration(seconds: 45),
  );

  Future<List<Map<String, dynamic>>> list({bool force = false}) async {
    if (_api.bearerToken == null) return const [];
    final now = DateTime.now();
    if (!force &&
        _listCache != null &&
        _listCacheAt != null &&
        now.difference(_listCacheAt!) < _listCacheTtl) {
      return _listCache!;
    }
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/entities',
      options: _entityWriteOptions,
    );
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
        'formation_state': ?formationState,
      },
      options: _entityWriteOptions,
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  Future<Map<String, dynamic>?> show(String entityId) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/entities/$entityId',
      options: _entityWriteOptions,
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  /// Ensure the client has at least one individual entity for tax-year workspaces.
  ///
  /// Retries once after a forced re-list so cold App Review accounts (no entity
  /// yet) still open Tax Organizer when the first create hits a transient 5xx.
  Future<Map<String, dynamic>?> ensurePrimaryEntity({String legalName = 'Primary filing'}) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final existing = await list(force: attempt > 0);
      if (existing.isNotEmpty) return existing.first;

      try {
        final created = await create(entityType: 'individual', legalName: legalName);
        _listCache = null;
        _listCacheAt = null;
        if (created != null && (created['id']?.toString() ?? '').isNotEmpty) {
          return created;
        }
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        final retryable = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError ||
            status == 502 ||
            status == 503 ||
            status == 504;
        if (!retryable || attempt >= 1) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 700));
        continue;
      }

      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
    }
    return null;
  }
}

final entitiesRepositoryProvider = Provider<EntitiesRepository>((ref) {
  return EntitiesRepository(ref.watch(laravelApiClientProvider));
});
