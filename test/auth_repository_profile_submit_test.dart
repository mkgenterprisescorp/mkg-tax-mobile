import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/core/network/api_client.dart';
import 'package:mkg_tax_mobile/core/network/laravel_api_client.dart';
import 'package:mkg_tax_mobile/features/auth/data/auth_repository.dart';

class _SeqAdapter implements HttpClientAdapter {
  _SeqAdapter(this.handlers);

  final List<ResponseBody Function(RequestOptions options)> handlers;
  int _i = 0;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_i >= handlers.length) {
      return ResponseBody.fromString('{"message":"unexpected"}', 500);
    }
    return handlers[_i++](options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      LaravelApiClient.sanctumTokenStorageKey: 'test-token',
    });
    AuthRepository.debugUsesLaravelAuth = () => true;
  });

  tearDown(() {
    AuthRepository.debugUsesLaravelAuth = null;
  });

  test('profile submit omits null phone/line2 and maps success profile', () async {
    final adapter = _SeqAdapter([
      (o) {
        expect(o.path, '/api/v1/profile');
        expect(o.method, 'GET');
        return _json(200, {
          'data': {
            'external_user_id': 'u-1',
            'email': 'a@example.com',
            'name': 'Ada Lovelace',
            'version': 3,
            'approval_status': 'approved',
            'mailing_address': {
              'line1': '1 Main',
              'city': 'Fresno',
              'state': 'CA',
              'postal_code': '93726',
            },
          },
        });
      },
      (o) {
        expect(o.path, '/me');
        return _json(200, {
          'external_user_id': 'u-1',
          'claims': {'email': 'a@example.com', 'name': 'Ada Lovelace', 'role': 'client'},
        });
      },
      (o) {
        expect(o.path, '/api/v1/profile');
        expect(o.method, 'PATCH');
        final data = o.data as Map;
        expect(data.containsKey('phone'), isFalse);
        final mailing = Map<String, dynamic>.from(data['mailing_address'] as Map);
        expect(mailing.containsKey('line2'), isFalse);
        expect(mailing['line1'], '4021 North Fresno Street');
        return _json(200, {
          'data': {
            'external_user_id': 'u-1',
            'email': 'a@example.com',
            'name': 'Ada Lovelace',
            'phone': null,
            'version': 4,
            'approval_status': 'approved',
            'mailing_address': {
              'line1': '4021 North Fresno Street',
              'city': 'Fresno',
              'state': 'CA',
              'postal_code': '93726',
            },
            'verification': {'email': true, 'phone': false},
          },
        });
      },
    ]);

    final laravelDio = Dio(
      BaseOptions(
        baseUrl: 'https://app.mkgtaxconsultants.com',
        validateStatus: (code) => code != null && code < 500,
      ),
    )..httpClientAdapter = adapter;
    final apiDio = Dio(
      BaseOptions(
        baseUrl: 'https://app.mkgtaxconsultants.com/api/v1',
        validateStatus: (code) => code != null && code < 500,
      ),
    )..httpClientAdapter = adapter;

    final laravel = LaravelApiClient(laravelDio)..setBearerToken('test-token');
    final api = ApiClient(apiDio, CookieJar());
    final repo = AuthRepository(api, laravel: laravel);

    final user = await repo.submitProfileForReview(
      phone: '',
      address: '4021 North Fresno Street',
      apartment: '',
      city: 'Fresno',
      state: 'CA',
      zipCode: '93726',
    );

    expect(user.email, 'a@example.com');
    expect(user.address, '4021 North Fresno Street');
    expect(user.kycStatus, 'approved');
  });

  test('profile submit rejects error-shaped HTTP 200 and does not wipe session', () async {
    final adapter = _SeqAdapter([
      (o) => _json(200, {
            'data': {
              'external_user_id': 'u-2',
              'email': 'b@example.com',
              'name': 'Grace Hopper',
              'version': 1,
              'approval_status': 'approved',
              'mailing_address': {
                'line1': '1 Main',
                'city': 'Oakland',
                'state': 'CA',
                'postal_code': '94607',
              },
            },
          }),
      (o) => _json(200, {
            'external_user_id': 'u-2',
            'claims': {'email': 'b@example.com', 'name': 'Grace Hopper', 'role': 'client'},
          }),
      (o) => _json(200, {
            'data': {
              'error': 'validation_error',
              'message': 'The request could not be validated.',
            },
          }),
    ]);

    final laravelDio = Dio(
      BaseOptions(
        baseUrl: 'https://app.mkgtaxconsultants.com',
        validateStatus: (code) => code != null && code < 500,
      ),
    )..httpClientAdapter = adapter;
    final apiDio = Dio(
      BaseOptions(
        baseUrl: 'https://app.mkgtaxconsultants.com/api/v1',
        validateStatus: (code) => code != null && code < 500,
      ),
    )..httpClientAdapter = adapter;

    final repo = AuthRepository(
      ApiClient(apiDio, CookieJar()),
      laravel: LaravelApiClient(laravelDio)..setBearerToken('test-token'),
    );

    await expectLater(
      () => repo.submitProfileForReview(
        phone: '5551112222',
        address: '1 Main',
        city: 'Oakland',
        state: 'CA',
        zipCode: '94607',
      ),
      throwsA(isA<AuthException>()),
    );
  });
}
