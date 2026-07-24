import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/core/network/api_client.dart';
import 'package:mkg_tax_mobile/features/auth/data/auth_repository.dart';

class _ApiAdapter implements HttpClientAdapter {
  _ApiAdapter({required this.statusCode, this.body});

  final int statusCode;
  final Object? body;
  String? lastPath;
  Object? lastData;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastData = options.data;
    final encoded = body == null
        ? '{}'
        : body is String
            ? body as String
            : jsonEncode(body);
    return ResponseBody.fromString(
      encoded,
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
  tearDown(() {
    AuthRepository.debugUsesLaravelAuth = null;
  });

  test('Laravel auth completes password reset via Sanctum confirm façade', () async {
    AuthRepository.debugUsesLaravelAuth = () => true;
    final adapter = _ApiAdapter(
      statusCode: 200,
      body: {'success': true, 'message': 'Password reset successfully.'},
    );
    final client = ApiClient.memory();
    client.dio.httpClientAdapter = adapter;

    final repo = AuthRepository(client);
    await repo.resetPassword(
      email: 'client@example.com',
      code: '123456',
      newPassword: 'NewPass12',
    );

    expect(adapter.lastPath, '/auth/password-reset/confirm');
    expect(adapter.lastData, {
      'email': 'client@example.com',
      'code': '123456',
      'new_password': 'NewPass12',
    });
  });

  test('Laravel auth maps invalid reset code to AuthException', () async {
    AuthRepository.debugUsesLaravelAuth = () => true;
    final adapter = _ApiAdapter(
      statusCode: 400,
      body: {
        'error': {
          'code': 'invalid_reset',
          'message': 'That code is invalid or has expired. Please request a new one.',
        },
      },
    );
    final client = ApiClient.memory();
    client.dio.httpClientAdapter = adapter;

    final repo = AuthRepository(client);
    await expectLater(
      () => repo.resetPassword(
        email: 'client@example.com',
        code: '000000',
        newPassword: 'NewPass12',
      ),
      throwsA(isA<AuthException>()),
    );
  });
}
