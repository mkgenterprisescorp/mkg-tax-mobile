import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

class AddressRepository {
  AddressRepository(this._api);
  final LaravelApiClient _api;

  /// Prefer Laravel Nominatim proxy; fall back to public OSM Nominatim if needed.
  Future<List<Map<String, dynamic>>> suggest(String query, {String mode = 'individual'}) async {
    if (query.trim().length < 3) return const [];
    if (_api.bearerToken != null) {
      final res = await _api.get<Map<String, dynamic>>(
        '/api/v1/address/autocomplete',
        query: {'q': query.trim(), 'mode': mode},
      );
      if (PlatformApi.ok(res)) {
        final map = PlatformApi.unwrapMap(res);
        final suggestions = map?['suggestions'];
        if (suggestions is List && suggestions.isNotEmpty) {
          return suggestions.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    }
    return _nominatimDirect(query.trim());
  }

  Future<List<Map<String, dynamic>>> _nominatimDirect(String query) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 8),
          headers: {
            'Accept': 'application/json',
            'Accept-Language': 'en',
            'User-Agent': 'MKGTaxMobile/1.0 (address-autocomplete; contact=support@mkgtaxconsultants.com)',
          },
        ),
      );
      final res = await dio.get<List<dynamic>>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'addressdetails': 1,
          'countrycodes': 'us',
          'limit': 5,
        },
      );
      final rows = res.data;
      if (rows == null || rows.isEmpty) return const [];
      final out = <Map<String, dynamic>>[];
      for (final row in rows.whereType<Map>()) {
        final addr = row['address'] is Map ? Map<String, dynamic>.from(row['address'] as Map) : const <String, dynamic>{};
        final house = '${addr['house_number'] ?? ''}'.trim();
        final road = '${addr['road'] ?? addr['pedestrian'] ?? ''}'.trim();
        final street = [if (house.isNotEmpty) house, if (road.isNotEmpty) road].join(' ').trim();
        final city = '${addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['hamlet'] ?? ''}'.trim();
        final stateRaw = '${addr['state'] ?? ''}'.trim();
        final state = _stateCode(stateRaw);
        final zip = '${addr['postcode'] ?? ''}'.trim().split('-').first;
        out.add({
          'place_id': '${row['place_id'] ?? ''}',
          'description': '${row['display_name'] ?? ''}',
          'street': street,
          'city': city,
          'state': state,
          'zip': zip,
        });
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static const _states = <String, String>{
    'Alabama': 'AL', 'Alaska': 'AK', 'Arizona': 'AZ', 'Arkansas': 'AR', 'California': 'CA',
    'Colorado': 'CO', 'Connecticut': 'CT', 'Delaware': 'DE', 'Florida': 'FL', 'Georgia': 'GA',
    'Hawaii': 'HI', 'Idaho': 'ID', 'Illinois': 'IL', 'Indiana': 'IN', 'Iowa': 'IA',
    'Kansas': 'KS', 'Kentucky': 'KY', 'Louisiana': 'LA', 'Maine': 'ME', 'Maryland': 'MD',
    'Massachusetts': 'MA', 'Michigan': 'MI', 'Minnesota': 'MN', 'Mississippi': 'MS', 'Missouri': 'MO',
    'Montana': 'MT', 'Nebraska': 'NE', 'Nevada': 'NV', 'New Hampshire': 'NH', 'New Jersey': 'NJ',
    'New Mexico': 'NM', 'New York': 'NY', 'North Carolina': 'NC', 'North Dakota': 'ND',
    'Ohio': 'OH', 'Oklahoma': 'OK', 'Oregon': 'OR', 'Pennsylvania': 'PA', 'Rhode Island': 'RI',
    'South Carolina': 'SC', 'South Dakota': 'SD', 'Tennessee': 'TN', 'Texas': 'TX', 'Utah': 'UT',
    'Vermont': 'VT', 'Virginia': 'VA', 'Washington': 'WA', 'West Virginia': 'WV', 'Wisconsin': 'WI',
    'Wyoming': 'WY', 'District of Columbia': 'DC',
  };

  String _stateCode(String raw) {
    if (raw.length == 2) return raw.toUpperCase();
    return _states[raw] ?? raw;
  }

  Future<Map<String, dynamic>?> details(String placeId) async {
    if (_api.bearerToken == null || placeId.isEmpty) return null;
    final res = await _api.get<Map<String, dynamic>>('/api/v1/address/details/$placeId');
    if (!PlatformApi.ok(res)) return null;
    final map = PlatformApi.unwrapMap(res);
    final details = map?['details'];
    if (details is Map) return Map<String, dynamic>.from(details);
    return map;
  }
}

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return AddressRepository(ref.watch(laravelApiClientProvider));
});
