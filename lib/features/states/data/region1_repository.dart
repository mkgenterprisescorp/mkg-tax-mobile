import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

/// Region 1 West form inventory + estimates.
class Region1Repository {
  Region1Repository(this._api);
  final LaravelApiClient _api;

  Map<String, dynamic>? _catalogCache;

  Future<Map<String, dynamic>> catalog({bool preferAsset = true}) async {
    if (_catalogCache != null) return _catalogCache!;
    try {
      final res = await _api.get<Map<String, dynamic>>('/api/v1/regions/1/forms');
      if (PlatformApi.ok(res)) {
        final map = PlatformApi.unwrapMap(res);
        if (map != null) {
          _catalogCache = map;
          return map;
        }
      }
    } catch (_) {
      // fall through to asset
    }
    if (preferAsset) {
      final raw = await rootBundle.loadString('assets/region1-west-forms-ty2025.json');
      _catalogCache = jsonDecode(raw) as Map<String, dynamic>;
      return _catalogCache!;
    }
    return {};
  }

  Future<Map<String, dynamic>?> estimate({
    required String stateCode,
    required Map<String, dynamic> input,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/api/v1/regions/1/estimate',
      data: {
        'state_code': stateCode.toUpperCase(),
        ...input,
      },
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  List<Map<String, dynamic>> formInventory(Map<String, dynamic> catalog) {
    final raw = catalog['form_inventory'] ?? catalog['formInventory'];
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }
}

final region1RepositoryProvider = Provider<Region1Repository>((ref) {
  return Region1Repository(ref.watch(laravelApiClientProvider));
});
