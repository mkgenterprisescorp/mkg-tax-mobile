import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/core/network/api_error_mapper.dart';

DioException _badResponse(int statusCode, {RequestOptions? options}) {
  final opts = options ?? RequestOptions(path: '/test');
  return DioException(
    requestOptions: opts,
    response: Response(requestOptions: opts, statusCode: statusCode),
    type: DioExceptionType.badResponse,
  );
}

void main() {
  group('ApiErrorMapper status-code mapping', () {
    test('401 maps to a session-expired message', () {
      final message = ApiErrorMapper.map(_badResponse(401));
      expect(message, ApiErrorMapper.loginSessionExpiredMessage);
      expect(message, isNot(contains('DioException')));
    });

    test('403 maps to a not-authorized message', () {
      expect(ApiErrorMapper.map(_badResponse(403)), contains('not authorized'));
    });

    test('404 maps to an unavailable message', () {
      expect(ApiErrorMapper.map(_badResponse(404)), contains('unavailable'));
    });

    test('422 maps to a safe validation message', () {
      expect(ApiErrorMapper.map(_badResponse(422)), contains('validated'));
    });

    test('429 maps to a too-many-attempts login message', () {
      expect(ApiErrorMapper.map(_badResponse(429)), ApiErrorMapper.loginTooManyAttemptsMessage);
    });

    test('500 maps to a server-unavailable login message', () {
      expect(ApiErrorMapper.map(_badResponse(500)), ApiErrorMapper.loginServerUnavailableMessage);
    });

    test('503 maps to a server-unavailable login message', () {
      expect(ApiErrorMapper.map(_badResponse(503)), ApiErrorMapper.loginServerUnavailableMessage);
    });

    test('timeout/connection errors map to a no-internet message', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ]) {
        final opts = RequestOptions(path: '/test');
        final err = DioException(requestOptions: opts, type: type);
        expect(ApiErrorMapper.map(err), ApiErrorMapper.loginNoInternetMessage);
      }
    });

    test('a non-Dio error maps to the generic safe message', () {
      expect(ApiErrorMapper.map(StateError('boom-should-never-appear')), ApiErrorMapper.genericMessage);
    });

    test('allowlisted organizer workspace StateErrors surface their message', () {
      expect(
        ApiErrorMapper.map(StateError('No tax-year workspace. Select a year and try again.')),
        'No tax-year workspace. Select a year and try again.',
      );
      expect(
        ApiErrorMapper.map(StateError('Please sign in again to open your tax organizer.')),
        'Please sign in again to open your tax organizer.',
      );
      expect(
        ApiErrorMapper.map(
          StateError('We’re unable to open your tax organizer right now. Please try again.'),
        ),
        'We’re unable to open your tax organizer right now. Please try again.',
      );
    });

    test('login mapper uses the approved client-facing copy', () {
      expect(ApiErrorMapper.mapLogin(_badResponse(401)), ApiErrorMapper.loginInvalidCredentialsMessage);
      expect(ApiErrorMapper.mapLogin(_badResponse(429)), ApiErrorMapper.loginTooManyAttemptsMessage);
      expect(ApiErrorMapper.mapLogin(_badResponse(500)), ApiErrorMapper.loginServerUnavailableMessage);
      expect(
        ApiErrorMapper.mapLogin(
          DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError),
        ),
        ApiErrorMapper.loginNoInternetMessage,
      );
    });

    test('no mapped message ever contains raw exception type names or file paths', () {
      final samples = [
        ApiErrorMapper.map(_badResponse(401)),
        ApiErrorMapper.map(_badResponse(403)),
        ApiErrorMapper.map(_badResponse(404)),
        ApiErrorMapper.map(_badResponse(422)),
        ApiErrorMapper.map(_badResponse(429)),
        ApiErrorMapper.map(_badResponse(500)),
        ApiErrorMapper.map(_badResponse(503)),
        ApiErrorMapper.map(StateError('internal detail that must never leak')),
        ApiErrorMapper.mapLogin(_badResponse(401)),
        ApiErrorMapper.mapLogin(_badResponse(500)),
      ];
      for (final message in samples) {
        expect(message, isNot(contains('DioException')));
        expect(message, isNot(contains('Exception')));
        expect(message, isNot(contains('.dart')));
        expect(message, isNot(contains('internal detail')));
        expect(message.toLowerCase(), isNot(contains('laravel')));
        expect(message.toLowerCase(), isNot(contains('sanctum')));
        expect(message.toLowerCase(), isNot(contains('neon')));
        expect(message, isNot(contains('/api/')));
      }
    });
  });
}
