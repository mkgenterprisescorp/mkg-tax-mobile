import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/core/network/api_client.dart';
import 'package:mkg_tax_mobile/features/auth/data/auth_repository.dart';

/// Custom adapter that reproduces production Dio transport behavior under
/// `validateStatus: (code) => code != null && code < 500`:
/// - status < 500 → Response resolves normally
/// - status >= 500 → Dio throws [DioExceptionType.badResponse]
/// - special [DioExceptionType] values → thrown before a response exists
class _TransportAdapter implements HttpClientAdapter {
  _TransportAdapter({
    this.statusCode,
    this.body,
    this.throwType,
  });

  final int? statusCode;
  final dynamic body;
  final DioExceptionType? throwType;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (throwType != null) {
      throw DioException(
        requestOptions: options,
        type: throwType!,
        message: 'transport-probe-${throwType!.name}',
      );
    }
    final code = statusCode ?? 200;
    final encoded = body == null
        ? '{}'
        : body is String
            ? body as String
            : jsonEncode(body);
    // Returning a >=500 status causes Dio (with validateStatus < 500) to
    // throw DioException.badResponse — matching production. Do NOT use
    // interceptor handler.resolve(500), which skips that path.
    return ResponseBody.fromString(
      encoded,
      code,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _clientWithAdapter(_TransportAdapter adapter) {
  final client = ApiClient.memory();
  // Preserve production validateStatus from ApiClient.memory().
  client.dio.httpClientAdapter = adapter;
  return client;
}

Future<void> _expectSilentCompletion(AuthRepository repo) async {
  await repo.requestPasswordReset('probe@example.com');
  // No exception — identical result for every transport outcome.
}

void main() {
  group('AuthRepository.requestPasswordReset — real transport paths', () {
    test('200 completes silently and ignores revealing response body', () async {
      final repo = AuthRepository(
        _clientWithAdapter(
          _TransportAdapter(
            statusCode: 200,
            body: {'message': 'Code sent to exists@example.com', 'exists': true},
          ),
        ),
      );
      await _expectSilentCompletion(repo);
    });

    test('404 completes silently and ignores "no account" body', () async {
      final repo = AuthRepository(
        _clientWithAdapter(
          _TransportAdapter(
            statusCode: 404,
            body: {'message': 'No account found for that email.'},
          ),
        ),
      );
      await _expectSilentCompletion(repo);
    });

    test('422 completes silently and ignores validation body', () async {
      final repo = AuthRepository(
        _clientWithAdapter(
          _TransportAdapter(
            statusCode: 422,
            body: {
              'errors': {
                'email': ['The email field is required.'],
              },
            },
          ),
        ),
      );
      await _expectSilentCompletion(repo);
    });

    test('429 completes silently and ignores rate-limit body', () async {
      final repo = AuthRepository(
        _clientWithAdapter(
          _TransportAdapter(
            statusCode: 429,
            body: {'message': 'Too many attempts, try again in 60 seconds.'},
          ),
        ),
      );
      await _expectSilentCompletion(repo);
    });

    test('500 throws badResponse from Dio and is normalized to silent success', () async {
      final dio = Dio(
        BaseOptions(validateStatus: (code) => code != null && code < 500),
      );
      dio.httpClientAdapter = _TransportAdapter(
        statusCode: 500,
        body: {'message': 'Internal server error: NullPointerException at line 42'},
      );
      // Prove the adapter + validateStatus really throw (false-pass guard).
      await expectLater(
        () => dio.post('/api/forgot-password'),
        throwsA(
          isA<DioException>().having((e) => e.type, 'type', DioExceptionType.badResponse),
        ),
      );

      final repo = AuthRepository(
        _clientWithAdapter(
          _TransportAdapter(
            statusCode: 500,
            body: {'message': 'Internal server error: NullPointerException at line 42'},
          ),
        ),
      );
      await _expectSilentCompletion(repo);
    });

    test('503 throws badResponse from Dio and is normalized to silent success', () async {
      final repo = AuthRepository(
        _clientWithAdapter(
          _TransportAdapter(
            statusCode: 503,
            body: {'message': 'Service Unavailable — maintenance'},
          ),
        ),
      );
      await _expectSilentCompletion(repo);
    });

    test('connectionTimeout is normalized to silent success', () async {
      final repo = AuthRepository(
        _clientWithAdapter(
          _TransportAdapter(throwType: DioExceptionType.connectionTimeout),
        ),
      );
      await _expectSilentCompletion(repo);
    });

    test('connectionError is normalized to silent success', () async {
      final repo = AuthRepository(
        _clientWithAdapter(
          _TransportAdapter(throwType: DioExceptionType.connectionError),
        ),
      );
      await _expectSilentCompletion(repo);
    });

    test('all transport outcomes share the same public acknowledgement constant', () {
      expect(
        passwordResetAcknowledgement,
        'If an account matches the information provided, password reset instructions will be sent.',
      );
      expect(passwordResetAcknowledgement.toLowerCase(), isNot(contains('laravel')));
      expect(passwordResetAcknowledgement.toLowerCase(), isNot(contains('exists')));
    });
  });
}
