import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

/// Git-tracked state tax resources registry (agency / forms / refund / portals).
/// Prefers Laravel `GET /api/v1/reference/state-tax-resources`, falls back to
/// bundled `assets/tax/state-tax-resources.json`.
class StateTaxResourcesCatalog {
  StateTaxResourcesCatalog._();

  static Map<String, dynamic>? _cache;

  static Future<Map<String, dynamic>> loadBundled() async {
    if (_cache != null) return Map<String, dynamic>.from(_cache!);
    final raw = await rootBundle.loadString('assets/tax/state-tax-resources.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw StateError('state-tax-resources.json must be an object');
    }
    _cache = Map<String, dynamic>.from(decoded);
    return Map<String, dynamic>.from(_cache!);
  }

  static void clearCache() => _cache = null;
}

class StateTaxResource {
  const StateTaxResource({
    required this.code,
    required this.name,
    required this.regionId,
    required this.regionName,
    required this.agencyUrl,
    required this.formsUrl,
    required this.refundTrackerUrl,
    required this.efileUrl,
    required this.taxpayerPortalUrl,
    required this.hasPersonalIncomeTax,
    required this.formUrls,
  });

  final String code;
  final String name;
  final String regionId;
  final String regionName;
  final String? agencyUrl;
  final String? formsUrl;
  final String? refundTrackerUrl;
  final String? efileUrl;
  final String? taxpayerPortalUrl;
  final bool hasPersonalIncomeTax;
  final Map<String, String?> formUrls;

  factory StateTaxResource.fromJson(Map<String, dynamic> json) {
    final formUrlsRaw = json['form_urls'];
    final formUrls = <String, String?>{};
    if (formUrlsRaw is Map) {
      formUrlsRaw.forEach((k, v) {
        formUrls['$k'] = v?.toString();
      });
    }
    return StateTaxResource(
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? json['code'] ?? '').toString(),
      regionId: (json['region_id'] ?? '').toString(),
      regionName: (json['region_name'] ?? '').toString(),
      agencyUrl: json['agency_url']?.toString(),
      formsUrl: json['forms_url']?.toString(),
      refundTrackerUrl: json['refund_tracker_url']?.toString(),
      efileUrl: json['efile_url']?.toString(),
      taxpayerPortalUrl: json['taxpayer_portal_url']?.toString(),
      hasPersonalIncomeTax: json['has_personal_income_tax'] == true,
      formUrls: formUrls,
    );
  }
}

class StateTaxResourcesRepository {
  StateTaxResourcesRepository(this._api);
  final LaravelApiClient _api;

  Future<({Map<String, dynamic> federal, List<StateTaxResource> states, String source})> load() async {
    if (_api.bearerToken != null) {
      try {
        final res = await _api.get<Map<String, dynamic>>('/api/v1/reference/state-tax-resources');
        if (PlatformApi.ok(res)) {
          final map = PlatformApi.unwrapMap(res);
          if (map != null) {
            return _parse(map, source: 'laravel');
          }
        }
      } catch (_) {
        // Fall through to bundled registry.
      }
    }
    final bundled = await StateTaxResourcesCatalog.loadBundled();
    return _parse(bundled, source: 'bundled');
  }

  ({Map<String, dynamic> federal, List<StateTaxResource> states, String source}) _parse(
    Map<String, dynamic> map, {
    required String source,
  }) {
    final federal = Map<String, dynamic>.from((map['federal'] as Map?) ?? const {});
    final states = (map['states'] as List?)
            ?.whereType<Map>()
            .map((e) => StateTaxResource.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const <StateTaxResource>[];
    states.sort((a, b) => a.name.compareTo(b.name));
    return (federal: federal, states: states, source: source);
  }
}

final stateTaxResourcesRepositoryProvider = Provider<StateTaxResourcesRepository>((ref) {
  return StateTaxResourcesRepository(ref.watch(laravelApiClientProvider));
});
