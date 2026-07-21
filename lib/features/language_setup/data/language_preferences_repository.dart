import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';
import '../../../core/localization/locale_controller.dart';

class LanguagePreferencesRepository {
  LanguagePreferencesRepository(this._api);
  final LaravelApiClient _api;

  Future<Map<String, dynamic>?> fetchPreferences() async {
    if (_api.bearerToken == null) return null;
    final res = await _api.get<Map<String, dynamic>>('/api/v1/tessa/languages/preferences');
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  Future<Map<String, dynamic>?> savePreferences(LanguagePreferences prefs) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.put<Map<String, dynamic>>(
      '/api/v1/tessa/languages/preferences',
      data: prefs.toApiBody(),
    );
    if (!PlatformApi.ok(res)) {
      throw StateError('Failed to save language preferences');
    }
    return PlatformApi.unwrapMap(res);
  }

  Future<Map<String, dynamic>?> fetchLocales({int phase = 1}) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/tessa/languages',
      query: {'phase': phase},
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  Future<Map<String, dynamic>?> fetchRegionalPriorities(String regionId) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/tessa/languages/regions/$regionId',
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }
}
