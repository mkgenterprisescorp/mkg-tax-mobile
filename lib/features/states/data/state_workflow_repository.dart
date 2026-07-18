import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

/// Nationwide personal + business state workflow catalog (intake_only).
class StateWorkflowRepository {
  StateWorkflowRepository(this._api);
  final LaravelApiClient _api;

  final Map<String, Map<String, dynamic>> _jurisdictionCache = {};

  Future<Map<String, dynamic>?> summary({int taxYear = 2025}) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/states/workflows',
      query: {'tax_year': taxYear},
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  Future<Map<String, dynamic>?> jurisdiction(
    String stateCode, {
    int taxYear = 2025,
    String? family,
    String? filingType,
  }) async {
    final code = stateCode.toUpperCase();
    if (code == 'CA') return null;
    final cacheKey = '$code|$taxYear|${family ?? ''}|${filingType ?? ''}';
    if (_jurisdictionCache.containsKey(cacheKey)) {
      return _jurisdictionCache[cacheKey];
    }
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/states/$code/workflows',
      query: {
        'tax_year': taxYear,
        'family': ?family,
        'filing_type': ?filingType,
      },
    );
    if (!PlatformApi.ok(res)) return null;
    final map = PlatformApi.unwrapMap(res);
    if (map != null) _jurisdictionCache[cacheKey] = map;
    return map;
  }

  Future<Map<String, dynamic>?> findReturn({
    required String stateCode,
    required String family,
    required String filingType,
    int taxYear = 2025,
  }) async {
    final doc = await jurisdiction(
      stateCode,
      taxYear: taxYear,
      family: family,
      filingType: filingType,
    );
    final returns = doc?['returns'];
    if (returns is! List || returns.isEmpty) return null;
    final first = returns.first;
    if (first is Map) return Map<String, dynamic>.from(first);
    return null;
  }

  Future<Map<String, dynamic>?> evaluate({
    required String stateCode,
    required String family,
    required String filingType,
    required Map<String, dynamic> answers,
  }) async {
    final code = stateCode.toUpperCase();
    if (code == 'CA') return null;
    final res = await _api.post<Map<String, dynamic>>(
      '/api/v1/states/$code/workflows/evaluate',
      data: {
        'return_family': family,
        'filing_type': filingType,
        'answers': answers,
      },
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }
}

final stateWorkflowRepositoryProvider = Provider<StateWorkflowRepository>((ref) {
  return StateWorkflowRepository(ref.watch(laravelApiClientProvider));
});

/// Map Flutter prepType / entity type → engine returnFamily.
String returnFamilyForPrepType(String prepType) {
  switch (prepType) {
    case 'form1120':
      return 'corporation';
    case 'form1120S':
      return 's_corporation';
    case 'form1065':
      return 'partnership';
    case 'form1041':
      return 'fiduciary';
    case 'form990':
      return 'exempt_organization';
    case 'form990EZ':
      return 'exempt_organization_ez';
    default:
      return 'individual';
  }
}

String filingTypeForResidency(String residency) {
  switch (residency) {
    case 'resident':
      return 'resident';
    case 'part_year':
      return 'part_year';
    case 'nonresident':
      return 'nonresident';
    default:
      return 'resident';
  }
}
