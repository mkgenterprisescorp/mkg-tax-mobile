import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

class StatesRepository {
  StatesRepository(this._api);
  final LaravelApiClient _api;

  Future<List<String>> catalog({required int taxYear}) async {
    final details = await catalogDetails(taxYear: taxYear);
    if (details.isNotEmpty) {
      return details.map((e) => e['code'].toString()).toList();
    }
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/states',
      query: {'tax_year': taxYear},
    );
    if (!PlatformApi.ok(res)) return const [];
    final map = PlatformApi.unwrapMap(res);
    final states = map?['states'];
    if (states is List) return states.map((e) => e.toString()).toList();
    return const [];
  }

  /// Enriched catalog: address availability is separate from tax filing support.
  Future<List<Map<String, dynamic>>> catalogDetails({required int taxYear}) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/reference/states',
      query: {'tax_year': taxYear},
    );
    if (!PlatformApi.ok(res)) {
      // Fallback to legacy /states payload shape.
      final legacy = await _api.get<Map<String, dynamic>>(
        '/api/v1/states',
        query: {'tax_year': taxYear},
      );
      if (!PlatformApi.ok(legacy)) return const [];
      final map = PlatformApi.unwrapMap(legacy);
      final details = map?['state_details'];
      if (details is List) {
        return details.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      final states = map?['states'];
      if (states is List) {
        return states
            .map((e) => <String, dynamic>{'code': e.toString(), 'tax_filing_support': e.toString() == 'CA' ? 'organizer_supported' : 'unsupported'})
            .toList();
      }
      return const [];
    }
    final map = PlatformApi.unwrapMap(res);
    final states = map?['states'];
    if (states is! List) return const [];
    return states.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>?> rules(String stateCode, {required int taxYear}) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/states/$stateCode/rules',
      query: {'tax_year': taxYear},
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  Future<Map<String, dynamic>?> upsertWorkspaceState({
    required String workspaceId,
    required String stateCode,
    required String residencyType,
    Map<String, dynamic>? answers,
    Map<String, dynamic>? nexus,
  }) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.put<Map<String, dynamic>>(
      '/api/v1/tax-year-workspaces/$workspaceId/states',
      data: {
        'state_code': stateCode,
        'residency_type': residencyType,
        if (answers != null) 'answers': answers,
        if (nexus != null) 'nexus': nexus,
      },
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }
}

final statesRepositoryProvider = Provider<StatesRepository>((ref) {
  return StatesRepository(ref.watch(laravelApiClientProvider));
});
