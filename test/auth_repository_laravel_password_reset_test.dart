import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/core/network/api_client.dart';
import 'package:mkg_tax_mobile/features/auth/data/auth_repository.dart';

class _PortalAdapter implements HttpClientAdapter {
  _PortalAdapter({required this.statusCode, this.body});

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

  test('Laravel auth completes password reset via portal /api/reset-password', () async {
    AuthRepository.debugUsesLaravelAuth = () => true;
    final adapter = _PortalAdapter(
      statusCode: 200,
      body: {'success': true, 'message': 'Password reset successfully.'},
    );
    final portal = Dio(
      BaseOptions(
        baseUrl: 'https://mkgtaxconsultants.com',
        validateStatus: (code) => code != null && code < 500,
      ),
    )..httpClientAdapter = adapter;

    final repo = AuthRepository(ApiClient.memory(), portalClient: portal);
    await repo.resetPassword(
      email: 'client@example.com',
      code: '123456',
      newPassword: 'NewPass12',
    );

    expect(adapter.lastPath, '/api/reset-password');
    expect(adapter.lastData, {
      'email': 'client@example.com',
      'code': '123456',
      'newPassword': 'NewPass12',
    });
  });

  test('Laravel auth maps invalid reset code to AuthException', () async {
    AuthRepository.debugUsesLaravelAuth = () => true;
    final adapter = _PortalAdapter(
      statusCode: 401,
      body: {'message': 'Invalid or expired reset code'},
    );
    final portal = Dio(
      BaseOptions(
        baseUrl: 'https://mkgtaxconsultants.com',
        validateStatus: (code) => code != null && code < 500,
      ),
    )..httpClientAdapter = adapter;

    final repo = AuthRepository(ApiClient.memory(), portalClient: portal);
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
