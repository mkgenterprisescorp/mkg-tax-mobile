import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/core/network/api_client.dart';
import 'package:mkg_tax_mobile/core/network/api_error_mapper.dart';
import 'package:mkg_tax_mobile/features/auth/data/auth_repository.dart';

class _LoginAdapter implements HttpClientAdapter {
  _LoginAdapter({required this.statusCode, required this.body});

  final int statusCode;
  final Map<String, dynamic> body;
  Map<String, dynamic>? lastData;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.data is Map) {
      lastData = Map<String, dynamic>.from(options.data as Map);
    } else if (options.data is String) {
      lastData = Map<String, dynamic>.from(jsonDecode(options.data as String) as Map);
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AuthRepository.debugUsesLaravelAuth = null;
  });

  test('login without otp throws requiresOtp on mfa_required 401', () async {
    AuthRepository.debugUsesLaravelAuth = () => true;
    final adapter = _LoginAdapter(
      statusCode: 401,
      body: {
        'error': 'mfa_required',
        'message': 'Enter the verification code sent to your email to continue.',
        'verification': {
          'mfa_required': true,
          'methods': ['email_otp'],
        },
      },
    );
    final client = ApiClient.memory();
    client.dio.httpClientAdapter = adapter;

    final repo = AuthRepository(client);
    await expectLater(
      repo.login(email: 'client@example.com', password: 'Secret1!'),
      throwsA(
        isA<AuthException>()
            .having((e) => e.requiresOtp, 'requiresOtp', isTrue)
            .having(
              (e) => e.message,
              'message',
              ApiErrorMapper.loginOtpRequiredMessage,
            ),
      ),
    );
    expect(adapter.lastData?['otp'], isNull);
    expect(adapter.lastData?['identifier'], 'client@example.com');
  });

  test('login forwards otp in Sanctum payload', () async {
    AuthRepository.debugUsesLaravelAuth = () => true;
    final adapter = _LoginAdapter(
      statusCode: 401,
      body: {
        'error': 'invalid_credentials',
        'message': 'The provided credentials are incorrect.',
      },
    );
    final client = ApiClient.memory();
    client.dio.httpClientAdapter = adapter;

    final repo = AuthRepository(client);
    await expectLater(
      repo.login(
        email: 'client@example.com',
        password: 'Secret1!',
        otp: '135790',
      ),
      throwsA(isA<AuthException>()),
    );
    expect(adapter.lastData?['otp'], '135790');
    expect(adapter.lastData?['identifier'], 'client@example.com');
    expect(adapter.lastData?['password'], 'Secret1!');
    expect(adapter.lastData?['device_name'], 'mkg-tax-mobile');
  });

  test('wrong otp keeps requiresOtp with invalid-code message', () async {
    AuthRepository.debugUsesLaravelAuth = () => true;
    final adapter = _LoginAdapter(
      statusCode: 401,
      body: {
        'error': 'mfa_required',
        'verification': {'mfa_required': true, 'methods': ['email_otp']},
      },
    );
    final client = ApiClient.memory();
    client.dio.httpClientAdapter = adapter;

    final repo = AuthRepository(client);
    await expectLater(
      repo.login(
        email: 'client@example.com',
        password: 'Secret1!',
        otp: '000000',
      ),
      throwsA(
        isA<AuthException>()
            .having((e) => e.requiresOtp, 'requiresOtp', isTrue)
            .having(
              (e) => e.message,
              'message',
              ApiErrorMapper.loginOtpInvalidMessage,
            ),
      ),
    );
  });
}
