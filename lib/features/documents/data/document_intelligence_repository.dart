import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

/// Catalog + extraction façade. No provider secrets in Flutter.
class DocumentIntelligenceRepository {
  DocumentIntelligenceRepository(this._api);
  final LaravelApiClient _api;

  Future<List<Map<String, dynamic>>> documentTypes() async {
    final res = await _api.get<Map<String, dynamic>>('/api/v1/reference/document-types');
    if (!PlatformApi.ok(res)) return const [];
    final map = PlatformApi.unwrapMap(res);
    final types = map?['types'];
    if (types is! List) return const [];
    return types.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>?> extractionHealth() async {
    final res = await _api.get<Map<String, dynamic>>('/api/v1/reference/extraction-health');
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  Future<Map<String, dynamic>?> eligibility(String workspaceId) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/tax-year-workspaces/$workspaceId/eligibility',
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  /// Starts portal-backed extraction for an already-uploaded document.
  Future<Map<String, dynamic>?> extractDocument({
    required String documentId,
    String? documentTypeHint,
    String? idempotencyKey,
  }) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/api/v1/documents/$documentId/extract',
      data: {
        if (documentTypeHint != null) 'document_type_hint': documentTypeHint,
      },
      options: Options(
        headers: {
          if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
        },
      ),
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  Future<Map<String, dynamic>?> extractionResult(String jobId) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.get<Map<String, dynamic>>('/api/v1/documents/extractions/$jobId');
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }
}

final documentIntelligenceRepositoryProvider = Provider<DocumentIntelligenceRepository>((ref) {
  return DocumentIntelligenceRepository(ref.watch(laravelApiClientProvider));
});
