import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';
import '../../../core/api/portal_repository.dart';

class RefundAdvanceRepository {
  RefundAdvanceRepository(this._api, this._portal);
  final LaravelApiClient _api;
  final PortalRepository _portal;

  Future<Map<String, dynamic>> calculateLoan(num amount, {int termDays = 29}) async {
    if (AppConfig.usesLaravelAuth && _api.bearerToken != null) {
      final res = await _api.post<Map<String, dynamic>>(
        '/api/v1/refund-advance/calculate',
        data: {'amount': amount, 'term_days': termDays},
      );
      if (!PlatformApi.ok(res)) throw StateError('Loan calculate failed');
      return PlatformApi.unwrapMap(res) ?? {};
    }
    return _portal.calculateLoan(amount);
  }

  Future<Map<String, dynamic>> tila(num amount) async {
    if (AppConfig.usesLaravelAuth && _api.bearerToken != null) {
      final res = await _api.post<Map<String, dynamic>>(
        '/api/v1/refund-advance/tila',
        data: {'amount': amount},
      );
      if (!PlatformApi.ok(res)) throw StateError('TILA fetch failed');
      return PlatformApi.unwrapMap(res) ?? {};
    }
    final quote = await _portal.calculateLoan(amount);
    return {'quote': quote, 'disclosure': null};
  }

  Future<Map<String, dynamic>> apply(Map<String, dynamic> payload) async {
    if (AppConfig.usesLaravelAuth && _api.bearerToken != null) {
      final res = await _api.post<Map<String, dynamic>>(
        '/api/v1/refund-advance/apply',
        data: {
          'amount': payload['amount'] ?? payload['amountRequested'],
          'tila_accepted': true,
          'tila_signed_name': payload['tilaSignedName'],
          'tier_label': payload['tierLabel'],
          'expected_refund': payload['expectedRefund'],
          'tax_return_id': payload['taxReturnId']?.toString(),
        },
      );
      if (!PlatformApi.ok(res)) throw StateError('Advance apply failed');
      return PlatformApi.unwrapMap(res) ?? {};
    }
    await _portal.applyLoan(payload);
    return {'status': 'submitted'};
  }

  Future<Map<String, dynamic>> estimateTax(Map<String, dynamic> inputs) async {
    if (AppConfig.usesLaravelAuth && _api.bearerToken != null) {
      final res = await _api.post<Map<String, dynamic>>('/api/v1/tax-estimates', data: inputs);
      if (!PlatformApi.ok(res)) throw StateError('Tax estimate failed');
      return PlatformApi.unwrapMap(res) ?? {};
    }
    throw StateError('Tax estimate requires Laravel API');
  }

  Future<Map<String, dynamic>?> form1040Preview(String workspaceId) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/tax-year-workspaces/$workspaceId/organizer/form-1040-preview',
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }
}

final refundAdvanceRepositoryProvider = Provider<RefundAdvanceRepository>((ref) {
  return RefundAdvanceRepository(
    ref.watch(laravelApiClientProvider),
    ref.watch(portalRepositoryProvider),
  );
});
