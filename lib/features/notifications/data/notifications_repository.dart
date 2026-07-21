import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

class NotificationsRepository {
  NotificationsRepository(this._api);
  final LaravelApiClient _api;

  /// Workflow-trigger inbox (document prompts, Apr/Oct filing, LLC/Corp notices).
  Future<({
    List<Map<String, dynamic>> items,
    Map<String, dynamic>? policy,
    Map<String, dynamic>? catalog,
  })> list({
    bool hasDocuments = false,
    String? prepType,
    bool llcCorpStarted = false,
    int? taxYear,
  }) async {
    if (_api.bearerToken == null) {
      return (
        items: const <Map<String, dynamic>>[],
        policy: null,
        catalog: null,
      );
    }
    final query = <String, dynamic>{
      'has_documents': hasDocuments ? '1' : '0',
      if (prepType != null && prepType.isNotEmpty) 'prep_type': prepType,
      'llc_corp_started': llcCorpStarted ? '1' : '0',
      if (taxYear != null) 'tax_year': taxYear,
    };
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/notifications',
      query: query,
    );
    if (!PlatformApi.ok(res)) {
      return (
        items: const <Map<String, dynamic>>[],
        policy: null,
        catalog: null,
      );
    }
    final map = PlatformApi.unwrapMap(res) ?? {};
    final items = (map['items'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const <Map<String, dynamic>>[];
    final policy =
        map['policy'] is Map ? Map<String, dynamic>.from(map['policy'] as Map) : null;
    final catalog =
        map['catalog'] is Map ? Map<String, dynamic>.from(map['catalog'] as Map) : null;
    return (items: items, policy: policy, catalog: catalog);
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(laravelApiClientProvider));
});
