import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

class InvoicesRepository {
  InvoicesRepository(this._api);
  final LaravelApiClient _api;

  /// Portal hosted-checkout floor (USD cents). Surfaced in Billing UI.
  static const int defaultMinimumCheckoutCents = 15000;

  Future<List<Map<String, dynamic>>> list() async {
    if (_api.bearerToken == null) return const [];
    final res = await _api.get<Map<String, dynamic>>('/api/v1/invoices');
    if (!PlatformApi.ok(res)) return const [];
    return PlatformApi.unwrapList(res);
  }

  /// Returns fee schedule items. Also stashes schedule meta on the last call
  /// via [feeScheduleMeta] for minimum checkout / currency.
  Future<List<Map<String, dynamic>>> feeSchedule() async {
    final res = await _api.get<Map<String, dynamic>>('/api/v1/billing/fee-schedule');
    if (!PlatformApi.ok(res)) {
      final fallback = await _api.get<Map<String, dynamic>>('/api/v1/reference/fee-schedule');
      if (!PlatformApi.ok(fallback)) return const [];
      final map = PlatformApi.unwrapMap(fallback);
      _lastFeeScheduleMeta = {
        'currency': map?['currency'] ?? 'usd',
        'minimum_checkout_cents': map?['minimum_checkout_cents'] ?? defaultMinimumCheckoutCents,
        'source': map?['source'] ?? 'reference',
      };
      final items = map?['items'];
      if (items is! List) return const [];
      return items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    final map = PlatformApi.unwrapMap(res);
    _lastFeeScheduleMeta = {
      'currency': map?['currency'] ?? 'usd',
      'minimum_checkout_cents': map?['minimum_checkout_cents'] ?? defaultMinimumCheckoutCents,
      'source': map?['source'] ?? 'billing',
      'note': map?['note'],
    };
    final items = map?['items'];
    if (items is! List) return const [];
    return items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Map<String, dynamic> _lastFeeScheduleMeta = {
    'currency': 'usd',
    'minimum_checkout_cents': defaultMinimumCheckoutCents,
  };

  Map<String, dynamic> get feeScheduleMeta => Map<String, dynamic>.from(_lastFeeScheduleMeta);

  /// Hosted Stripe Checkout via Laravel → portal. Never collects card data in-app.
  Future<Map<String, dynamic>> checkout(String invoiceId, {String? idempotencyKey}) async {
    if (_api.bearerToken == null) {
      throw StateError('Please sign in again to continue checkout.');
    }
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/api/v1/invoices/$invoiceId/checkout',
      options: Options(
        headers: {
          if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
        },
      ),
    );
    if (!PlatformApi.ok(res)) {
      throw StateError(_checkoutFailureMessage(res));
    }
    final map = PlatformApi.unwrapMap(res);
    if (map == null) {
      throw StateError('We’re unable to start checkout right now. Please try again.');
    }
    return map;
  }

  Future<Map<String, dynamic>> feeCheckout({
    required List<Map<String, dynamic>> services,
    int? taxYear,
    String? idempotencyKey,
  }) async {
    if (_api.bearerToken == null) {
      throw StateError('Please sign in again to continue checkout.');
    }
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/api/v1/billing/fee-checkout',
      data: {
        'services': services,
        if (taxYear != null) 'tax_year': taxYear,
      },
      options: Options(
        headers: {
          if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
        },
      ),
    );
    if (!PlatformApi.ok(res)) {
      throw StateError(_checkoutFailureMessage(res));
    }
    final map = PlatformApi.unwrapMap(res);
    if (map == null) {
      throw StateError('We’re unable to start checkout right now. Please try again.');
    }
    return map;
  }

  static String _checkoutFailureMessage(Response<Map<String, dynamic>> res) {
    final data = res.data;
    String? message;
    if (data != null) {
      final err = data['error'];
      if (err is Map && err['message'] != null) {
        message = err['message'].toString();
      } else if (data['message'] != null) {
        message = data['message'].toString();
      }
    }
    final msg = (message ?? '').trim();
    if (msg.isNotEmpty && msg.length < 180 && !msg.contains('\n')) {
      return msg;
    }
    return 'We’re unable to start checkout right now. Please try again.';
  }
}

final invoicesRepositoryProvider = Provider<InvoicesRepository>((ref) {
  return InvoicesRepository(ref.watch(laravelApiClientProvider));
});
