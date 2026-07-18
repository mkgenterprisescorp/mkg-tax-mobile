import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';
import '../../../core/api/portal_repository.dart';
import 'loan_calculator.dart';

class RefundAdvanceRepository {
  RefundAdvanceRepository(
    this._api,
    this._portal, {
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final LaravelApiClient _api;
  final PortalRepository _portal;
  final FlutterSecureStorage _storage;

  static const _tokenKey = 'mkg_sanctum_token';

  Future<void> _ensureLaravelToken() async {
    if (_api.bearerToken != null && _api.bearerToken!.isNotEmpty) return;
    final token = await _storage.read(key: _tokenKey);
    if (token != null && token.isNotEmpty) {
      _api.setBearerToken(token);
    }
  }

  /// Loan estimate — uses Laravel when authenticated, otherwise identical local math.
  /// Never depends on the legacy portal `/api/loans/calculate` path in Laravel mode
  /// (that path 404s against `app.mkgtaxconsultants.com/api/v1`).
  Future<Map<String, dynamic>> calculateLoan(num amount, {int termDays = 29}) async {
    final local = LoanCalculator.calculate(amount, termDays: termDays);

    if (!AppConfig.usesLaravelAuth) {
      try {
        final remote = await _portal.calculateLoan(amount);
        return {...local, ...remote, 'source': 'portal'};
      } catch (_) {
        return local;
      }
    }

    await _ensureLaravelToken();
    if (_api.bearerToken == null) {
      // Still show a correct estimate; apply/TILA require auth later.
      return local;
    }

    try {
      final res = await _api.post<Map<String, dynamic>>(
        '/api/v1/refund-advance/calculate',
        data: {'amount': amount, 'term_days': termDays},
      );
      final code = res.statusCode ?? 500;
      if (code >= 400) {
        // Fall back to local math so the Loan Estimate screen never dead-ends.
        return {...local, 'source': 'local_fallback', 'api_status': code};
      }
      final remote = PlatformApi.unwrapMap(res);
      if (remote == null || remote.isEmpty) return local;
      return {...local, ...remote, 'source': 'laravel'};
    } catch (e) {
      // Network blip — local Pathward math still valid for estimate UI.
      return {...local, 'source': 'local_fallback', 'api_error': ApiErrorMapper.map(e)};
    }
  }

  Future<Map<String, dynamic>> tila(num amount) async {
    final quote = LoanCalculator.calculate(amount);
    if (AppConfig.usesLaravelAuth) {
      await _ensureLaravelToken();
      if (_api.bearerToken == null) {
        throw StateError(ApiErrorMapper.loginSessionExpiredMessage);
      }
      final res = await _api.post<Map<String, dynamic>>(
        '/api/v1/refund-advance/tila',
        data: {'amount': amount},
      );
      if (!PlatformApi.ok(res)) {
        throw StateError(ApiErrorMapper.mapStatusCode(res.statusCode));
      }
      return PlatformApi.unwrapMap(res) ?? {'quote': quote, 'disclosure': null};
    }
    return {'quote': quote, 'disclosure': null};
  }

  Future<Map<String, dynamic>> apply(Map<String, dynamic> payload) async {
    if (AppConfig.usesLaravelAuth) {
      await _ensureLaravelToken();
      if (_api.bearerToken == null) {
        throw StateError(ApiErrorMapper.loginSessionExpiredMessage);
      }
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
      if (!PlatformApi.ok(res)) {
        throw StateError(ApiErrorMapper.mapStatusCode(res.statusCode));
      }
      return PlatformApi.unwrapMap(res) ?? {};
    }
    await _portal.applyLoan(payload);
    return {'status': 'submitted'};
  }

  Future<Map<String, dynamic>> estimateTax(Map<String, dynamic> inputs) async {
    if (AppConfig.usesLaravelAuth) {
      await _ensureLaravelToken();
      if (_api.bearerToken == null) {
        throw StateError(ApiErrorMapper.loginSessionExpiredMessage);
      }
      final res = await _api.post<Map<String, dynamic>>('/api/v1/tax-estimates', data: inputs);
      if (!PlatformApi.ok(res)) {
        throw StateError(ApiErrorMapper.mapStatusCode(res.statusCode));
      }
      return PlatformApi.unwrapMap(res) ?? {};
    }
    throw StateError('Tax estimate requires Laravel API');
  }

  Future<Map<String, dynamic>?> form1040Preview(String workspaceId) async {
    await _ensureLaravelToken();
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
