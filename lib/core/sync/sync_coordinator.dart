import 'dart:async';

import 'package:dio/dio.dart';

import '../network/laravel_api_client.dart';
import 'sync_cursor_store.dart';
import 'sync_models.dart';

typedef SyncAccountKeyResolver = FutureOr<String?> Function();

class SyncCoordinator {
  SyncCoordinator(
    this._api,
    this._store,
    this._accountKeyResolver, {
    this._retryBaseDelay = const Duration(milliseconds: 300),
    this._maxAttempts = 3,
  });

  final LaravelApiClient _api;
  final SyncCursorStore _store;
  final SyncAccountKeyResolver _accountKeyResolver;
  final Duration _retryBaseDelay;
  final int _maxAttempts;

  Future<SyncPullResult>? _pullInFlight;

  bool get debugPullInFlight => _pullInFlight != null;

  bool get debugHasPollingTimer => false;

  Future<SyncPullResult> pull({String reason = 'manual'}) {
    final existing = _pullInFlight;
    if (existing != null) return existing;
    final inFlight = _pullWithRetry(reason: reason);
    _pullInFlight = inFlight;
    unawaited(
      inFlight.then<void>(
        (_) {
          if (identical(_pullInFlight, inFlight)) _pullInFlight = null;
        },
        onError: (_) {
          if (identical(_pullInFlight, inFlight)) _pullInFlight = null;
        },
      ),
    );
    return inFlight;
  }

  Future<SyncPullResult> notifyLocalWriteSucceeded({
    String reason = 'local_write',
  }) {
    return pull(reason: reason);
  }

  Future<void> clearAccount({String? accountKey}) async {
    final key = accountKey ?? await _accountKeyResolver();
    if (key == null || key.isEmpty) return;
    await _store.clearAccount(key);
  }

  Future<SyncPullResult> _pullWithRetry({required String reason}) async {
    var attempt = 0;
    while (true) {
      try {
        return await _pullOnce(reason: reason);
      } on DioException catch (error) {
        attempt++;
        if (!_isRetryable(error) || attempt >= _maxAttempts) rethrow;
        await Future<void>.delayed(_delayForAttempt(attempt));
      }
    }
  }

  Future<SyncPullResult> _pullOnce({required String reason}) async {
    if (_api.bearerToken == null) return SyncPullResult.empty;
    final accountKey = await _accountKeyResolver();
    if (accountKey == null || accountKey.isEmpty) return SyncPullResult.empty;

    final cursor = await _store.readCursor(accountKey);
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/sync',
      query: {'cursor': cursor ?? '', 'reason': reason},
    );
    final status = response.statusCode ?? 500;
    if (status >= 400) {
      throw SyncException('Unable to sync account changes right now.');
    }
    final body = response.data ?? const <String, dynamic>{};
    final result = SyncPullResult.fromJson(body);
    if (result.nextCursor != null && result.nextCursor!.isNotEmpty) {
      await _store.writeCursor(accountKey, result.nextCursor!);
    }
    await _applyServerChanges(accountKey, result.events);
    return result;
  }

  Future<void> _applyServerChanges(
    String accountKey,
    List<SyncEventEnvelope> events,
  ) async {
    if (events.isEmpty) return;
    final summaries = Map<String, SyncCachedSummary>.from(
      await _store.readCachedSummaries(accountKey),
    );
    var changed = false;
    for (final event in events) {
      final existing = summaries[event.cacheKey];
      if (existing != null && existing.entityVersion >= event.entityVersion) {
        continue;
      }
      summaries[event.cacheKey] = event.toCachedSummary();
      changed = true;
    }
    if (changed) await _store.writeCachedSummaries(accountKey, summaries);
  }

  bool _isRetryable(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return true;
    }
    final status = error.response?.statusCode ?? 0;
    return status == 0 || status == 408 || status == 429 || status >= 500;
  }

  Duration _delayForAttempt(int attempt) {
    if (_retryBaseDelay == Duration.zero) return Duration.zero;
    final multiplier = 1 << (attempt - 1);
    return Duration(milliseconds: _retryBaseDelay.inMilliseconds * multiplier);
  }
}
