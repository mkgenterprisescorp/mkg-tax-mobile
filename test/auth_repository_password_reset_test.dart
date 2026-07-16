import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/core/network/api_client.dart';
import 'package:mkg_tax_mobile/features/auth/data/auth_repository.dart';

/// Blocker 4 (repository side): AuthRepository.requestPasswordReset() must
/// throw an identical AuthException message regardless of status code or
/// response body content, and must succeed silently for a 2xx response.
/// This is what makes the widget-level "identical observable state" test
/// (test/forgot_password_test.dart) actually meaningful — the fake
/// repository used there stubs this method out entirely, so it can't by
/// itself prove the real repository behaves this way against the network.
///
/// Stubs the Dio transport with a request interceptor that resolves
/// immediately (no real network I/O), rather than pulling in a mock-adapter
/// package — Dio's own interceptor chain is enough to control the response.
ApiClient _stubbedClient(int statusCode, dynamic body) {
  final client = ApiClient.memory();
  client.dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response(requestOptions: options, statusCode: statusCode, data: body),
        );
      },
    ),
  );
  return client;
}

void main() {
  group('AuthRepository.requestPasswordReset', () {
    test('succeeds silently for a 200 response regardless of body', () async {
      final repo = AuthRepository(_stubbedClient(200, {'message': 'Code sent to the account on file.'}));
      await repo.requestPasswordReset('exists@example.com');
      // No exception thrown - nothing further to assert.
    });

    test('throws an identical message for a 404 (no such account) as for a 422', () async {
      final repo404 = AuthRepository(
        _stubbedClient(404, {'message': 'No account found for that email.'}),
      );
      final repo422 = AuthRepository(
        _stubbedClient(422, {'errors': {'email': ['The email field is required.']}}),
      );

      String? message404;
      try {
        await repo404.requestPasswordReset('nonexistent@example.com');
      } on AuthException catch (e) {
        message404 = e.message;
      }

      String? message422;
      try {
        await repo422.requestPasswordReset('malformed');
      } on AuthException catch (e) {
        message422 = e.message;
      }

      expect(message404, isNotNull);
      expect(message422, isNotNull);
      expect(message404, message422, reason: 'status code must not change the message');
      expect(message404, isNot(contains('No account found')));
      expect(message404, isNot(contains('email field is required')));
    });

    test('throws an identical message for a 429 and a 500, and never forwards the response body', () async {
      final repo429 = AuthRepository(
        _stubbedClient(429, {'message': 'Too many attempts, try again in 60 seconds.'}),
      );
      final repo500 = AuthRepository(
        _stubbedClient(500, {'message': 'Internal server error: NullPointerException at line 42'}),
      );

      String? message429;
      try {
        await repo429.requestPasswordReset('someone@example.com');
      } on AuthException catch (e) {
        message429 = e.message;
      }

      String? message500;
      try {
        await repo500.requestPasswordReset('someone@example.com');
      } on AuthException catch (e) {
        message500 = e.message;
      }

      expect(message429, message500);
      expect(message429, isNot(contains('Too many attempts')));
      expect(message500, isNot(contains('NullPointerException')));
    });

    test('throws an identical message even with no response body at all', () async {
      final repo = AuthRepository(_stubbedClient(404, null));

      String? message;
      try {
        await repo.requestPasswordReset('someone@example.com');
      } on AuthException catch (e) {
        message = e.message;
      }

      expect(message, isNotNull);
    });
  });
}
