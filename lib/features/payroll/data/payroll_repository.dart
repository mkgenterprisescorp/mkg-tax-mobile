import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

class PayrollRepository {
  PayrollRepository(this._api);
  final LaravelApiClient _api;

  Future<Map<String, dynamic>?> calculate({
    required int taxYear,
    required num grossPay,
    required String payFrequency,
    String? stateCode,
  }) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.post<Map<String, dynamic>>(
      '/api/v1/payroll-calculations',
      data: {
        'tax_year': taxYear,
        'gross_pay': grossPay,
        'pay_frequency': payFrequency,
        if (stateCode != null) 'state_code': stateCode,
      },
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  Future<Map<String, dynamic>?> w4Estimate({
    required num annualWages,
    required String filingStatus,
  }) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.post<Map<String, dynamic>>(
      '/api/v1/w4-estimates',
      data: {
        'annual_wages': annualWages,
        'filing_status': filingStatus,
      },
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }
}

final payrollRepositoryProvider = Provider<PayrollRepository>((ref) {
  return PayrollRepository(ref.watch(laravelApiClientProvider));
});
