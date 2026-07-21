import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';
import '../../organizer/data/rollout_regions.dart';

/// Regional state-tax estimate client for Regions 1–6.
///
/// Region 1 uses `/api/v1/regions/1/estimate` (legacy Region 1 payload).
/// Regions 2–6 use `/api/v1/regions/{n}/estimate` (StateTaxRouter result).
/// Tax math stays on Laravel — Flutter only posts inputs and displays results.
class RegionalStateTaxRepository {
  RegionalStateTaxRepository(this._api);

  final LaravelApiClient _api;

  /// Prefer the region that owns [stateCode]; fall back to [regionId] when given.
  Future<Map<String, dynamic>?> estimatePersonal({
    required String stateCode,
    required Map<String, dynamic> input,
    String? regionId,
  }) async {
    final code = stateCode.toUpperCase();
    final region = regionId ?? regionForState(code)?.id;
    if (region == null || region.isEmpty) return null;

    final path = '/api/v1/regions/$region/estimate';
    final body = <String, dynamic>{
      'state': code,
      'state_code': code,
      'tax_year': input['tax_year'] ?? input['taxYear'] ?? 2025,
      ...input,
    };

    final res = await _api.post<Map<String, dynamic>>(path, data: body);
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  Future<Map<String, dynamic>?> regionFormsSummary(String regionId) async {
    final res = await _api.get<Map<String, dynamic>>('/api/v1/regions/$regionId/forms');
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }
}

final regionalStateTaxRepositoryProvider = Provider<RegionalStateTaxRepository>((ref) {
  return RegionalStateTaxRepository(ref.watch(laravelApiClientProvider));
});

/// Normalize Region 1 legacy + Regions 2–6 engine payloads for UI display.
class RegionalEstimateView {
  const RegionalEstimateView({
    required this.formLabel,
    required this.tax,
    required this.refundOrOwed,
    required this.disclaimer,
    required this.status,
    required this.taxRegime,
    required this.raw,
  });

  final String formLabel;
  final num tax;
  final num refundOrOwed;
  final String disclaimer;
  final String status;
  final String taxRegime;
  final Map<String, dynamic> raw;

  factory RegionalEstimateView.fromResponse(Map<String, dynamic> raw) {
    // Legacy Region 1 shape.
    if (raw.containsKey('refund_or_owed') || raw.containsKey('form')) {
      return RegionalEstimateView(
        formLabel: '${raw['form'] ?? '—'}',
        tax: _num(raw['tax']),
        refundOrOwed: _num(raw['refund_or_owed']),
        disclaimer:
            '${raw['disclaimer'] ?? 'Estimate only · live agency e-file off'}',
        status: '${raw['status'] ?? 'estimated'}',
        taxRegime: '${raw['meta'] is Map ? (raw['meta'] as Map)['tax_regime'] : raw['tax_regime'] ?? ''}',
        raw: raw,
      );
    }

    // StateTaxRouter personal result.
    String form = '—';
    final forms = raw['forms'];
    if (forms is List && forms.isNotEmpty && forms.first is Map) {
      form = '${(forms.first as Map)['form_code'] ?? (forms.first as Map)['form'] ?? '—'}';
    }

    final tax = _num(raw['gross_state_tax']);
    final refund = _num(raw['estimated_refund']);
    final due = _num(raw['balance_due']);
    final net = refund > 0 ? refund : (due > 0 ? -due : _num(raw['refund_or_owed']));

    return RegionalEstimateView(
      formLabel: form,
      tax: tax,
      refundOrOwed: net,
      disclaimer:
          'Region estimate for staff/client prep. Confirm with official state '
          'instructions before filing. Live agency e-file is not enabled.',
      status: '${raw['status'] ?? 'estimated'}',
      taxRegime: '${raw['tax_regime'] ?? ''}',
      raw: raw,
    );
  }

  static num _num(dynamic v) {
    if (v is num) return v;
    return num.tryParse('$v') ?? 0;
  }
}
