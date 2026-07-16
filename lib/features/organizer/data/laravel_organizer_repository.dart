import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

/// Server-driven organizer for Sanctum `/api/v1` builds.
class LaravelOrganizerRepository {
  LaravelOrganizerRepository(this._api);
  final LaravelApiClient _api;

  Future<Map<String, dynamic>?> show(String workspaceId, {String prepType = 'personal'}) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/tax-year-workspaces/$workspaceId/organizer',
      query: {'prep_type': prepType},
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  Future<Map<String, dynamic>?> updateSection({
    required String workspaceId,
    required String sectionKey,
    required Map<String, dynamic> answers,
    bool sectionComplete = false,
    String prepType = 'personal',
  }) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.put<Map<String, dynamic>>(
      '/api/v1/tax-year-workspaces/$workspaceId/organizer',
      data: {
        'prep_type': prepType,
        'section_key': sectionKey,
        'answers': answers,
        'section_complete': sectionComplete,
      },
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  Future<Map<String, dynamic>?> requestChange({
    required String organizerId,
    required Map<String, dynamic> payload,
  }) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.post<Map<String, dynamic>>(
      '/api/v1/organizers/$organizerId/change-requests',
      data: {'payload': payload},
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }
}

final laravelOrganizerRepositoryProvider = Provider<LaravelOrganizerRepository>((ref) {
  return LaravelOrganizerRepository(ref.watch(laravelApiClientProvider));
});
