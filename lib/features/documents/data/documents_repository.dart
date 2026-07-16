import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

class DocumentsRepository {
  DocumentsRepository(this._api);
  final LaravelApiClient _api;

  Future<List<Map<String, dynamic>>> list(String workspaceId) async {
    if (_api.bearerToken == null) return const [];
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/tax-year-workspaces/$workspaceId/documents',
    );
    if (!PlatformApi.ok(res)) return const [];
    return PlatformApi.unwrapList(res);
  }

  Future<Map<String, dynamic>?> upload({
    required String workspaceId,
    required String category,
    required MultipartFile file,
  }) async {
    if (_api.bearerToken == null) return null;
    final form = FormData.fromMap({
      'category': category,
      'file': file,
    });
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/api/v1/tax-year-workspaces/$workspaceId/documents',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  /// Returns a short-lived signed download URL. Never log the query string.
  Future<String?> signedDownloadUrl(String documentId) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.get<Map<String, dynamic>>('/api/v1/documents/$documentId/download');
    if (!PlatformApi.ok(res)) return null;
    final map = PlatformApi.unwrapMap(res);
    return map?['download_url']?.toString();
  }
}

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  return DocumentsRepository(ref.watch(laravelApiClientProvider));
});
